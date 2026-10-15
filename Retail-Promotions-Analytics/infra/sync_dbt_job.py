"""Publish the dbt project to the Fabric dbt job (dbt_promo_star_schema) and optionally run it.

The project is mirrored into the Lakehouse folder the job reads from (lh_silver > Files/dbt), including
dbt_packages/, so run `dbt deps` first. The job's Warehouse connection is left unchanged; only the dbt
command is updated, and only when different values are passed.

    python infra/sync_dbt_job.py                 # upload only
    python infra/sync_dbt_job.py --run           # upload, run the job, exit 1 if dbt reports errors
    python infra/sync_dbt_job.py --run --operation test --select "staging"

Auth: Azure CLI login locally, or the service principal from `azure/login` in CI.
"""
import argparse
import base64
import json
import pathlib
import re
import sys
import time

import requests
from azure.identity import AzureCliCredential
from azure.storage.filedatalake import DataLakeServiceClient

ONELAKE_URL = "https://onelake.dfs.fabric.microsoft.com"
API = "https://api.fabric.microsoft.com/v1"
REPO = pathlib.Path(__file__).resolve().parents[1]
DBT_DIR = REPO / "dbt"
SKIP_DIRS = {"target", "logs", ".venv", "__pycache__", ".git"}
SKIP_FILES = {"profiles.yml", ".user.yml", "package-lock.yml", ".gitkeep"}
PACKAGE_SKIP_DIRS = {"integration_tests", "docs", "tests"}

credential = AzureCliCredential()


def fabric(method: str, path: str, body: dict | None = None) -> requests.Response:
    token = credential.get_token("https://api.fabric.microsoft.com/.default").token
    url = path if path.startswith("http") else f"{API}{path}"
    res = requests.request(method, url, json=body, headers={"Authorization": f"Bearer {token}"}, timeout=60)
    if res.status_code >= 400:
        raise SystemExit(f"{method} {url} -> {res.status_code}: {res.text}")
    return res


def project_files():
    for f in sorted(DBT_DIR.rglob("*")):
        rel = f.relative_to(DBT_DIR)
        if f.is_dir() or f.name in SKIP_FILES or any(p in SKIP_DIRS for p in rel.parts):
            continue
        if any(p.startswith(".") for p in rel.parts):
            continue  # the dbt job cannot download projects containing dot-folders
        if rel.parts[0] == "dbt_packages" and len(rel.parts) > 2 and rel.parts[2] in PACKAGE_SKIP_DIRS:
            continue  # packages only need their macros at run time
        yield f, rel.as_posix()


def get_content(cfg: dict) -> dict:
    res = fabric("POST", f"/workspaces/{cfg['workspace_id']}/items/{cfg['dbt_job_id']}/getDefinition")
    parts = res.json()["definition"]["parts"]
    raw = next(p["payload"] for p in parts if p["path"] == "dbt-content.json")
    return json.loads(base64.b64decode(raw))


def put_content(cfg: dict, content: dict) -> None:
    payload = base64.b64encode(json.dumps(content, indent=2).encode()).decode()
    body = {"definition": {"parts": [{"path": "dbt-content.json", "payload": payload, "payloadType": "InlineBase64"}]}}
    fabric("POST", f"/workspaces/{cfg['workspace_id']}/items/{cfg['dbt_job_id']}/updateDefinition", body)


def project_location(content: dict) -> tuple[str, str, str]:
    """(workspace_id, lakehouse_id, folder under the lakehouse) the job reads its project from."""
    project = content.get("project", {})
    if project.get("projectType") != "Lakehouse":
        raise SystemExit(
            f"The job's project source is {project.get('projectType')!r}, not a Lakehouse. In Fabric open the dbt job, "
            "set the project source to lh_silver > Files/dbt, save, and re-run this script."
        )
    props = project["connectionSettings"]["properties"]
    tp = props.get("typeProperties", props)
    parts = [p.strip("/") for p in (tp.get("rootFolder", ""), project.get("folderPath", "")) if p and p.strip("/")]
    folder = "/".join(parts)
    if not folder.startswith(("Files", "Tables")):
        folder = f"Files/{folder}" if folder else "Files"
    return tp["workspaceId"], tp["artifactId"], folder


def mirror(workspace_id: str, lakehouse_id: str, folder: str) -> tuple[int, int]:
    fs = DataLakeServiceClient(ONELAKE_URL, credential=credential).get_file_system_client(workspace_id)
    root = f"{lakehouse_id}/{folder}"
    fs.get_directory_client(root).create_directory()
    local = dict((rel, f) for f, rel in project_files())
    for rel, f in local.items():
        fs.get_file_client(f"{root}/{rel}").upload_data(f.read_bytes(), overwrite=True)
    removed = 0
    for p in fs.get_paths(root, recursive=True):
        rel = p.name.split(f"/{folder}/", 1)[1]
        if not p.is_directory and rel not in local:
            fs.get_file_client(p.name).delete_file()
            removed += 1
    return len(local), removed


def dbt_log_summary(cfg: dict, run_id: str) -> dict | None:
    """Parse the run's logs/dbt.log (JSON lines) for dbt's own result: warnings, errors and the Done. counts."""
    fs = DataLakeServiceClient(ONELAKE_URL, credential=credential).get_file_system_client(cfg["workspace_id"])
    try:
        raw = fs.get_file_client(f"{cfg['dbt_job_id']}/Output/{run_id}/logs/dbt.log").download_file().readall()
    except Exception:
        return None
    problems, done = [], None
    for line in raw.decode(errors="replace").splitlines():
        try:
            info = json.loads(line).get("info", {})
        except ValueError:
            continue
        msg = re.sub(r"\x1b\[[0-9;]*m", "", info.get("msg", ""))
        if info.get("level") in ("warn", "error") and " of " in msg:
            problems.append(f"  [{info['level']}] {msg.strip()}")
        m = re.search(r"Done\. PASS=(\d+) WARN=(\d+) ERROR=(\d+) SKIP=(\d+)", msg)
        if m:
            done = dict(zip(("pass", "warn", "error", "skip"), map(int, m.groups())))
    return {"done": done, "problems": problems} if done else None


def run_job(cfg: dict, poll_seconds: int = 15, timeout_minutes: int = 60) -> bool:
    res = fabric("POST", f"/workspaces/{cfg['workspace_id']}/items/{cfg['dbt_job_id']}/jobs/instances?jobType=Execute")
    location = res.headers["Location"]
    run_id = location.rsplit("/", 1)[-1]
    print(f"Started dbt job run: {run_id}", flush=True)
    deadline = time.time() + timeout_minutes * 60
    while time.time() < deadline:
        time.sleep(poll_seconds)
        job = fabric("GET", location).json()
        status = job.get("status")
        if status not in ("Completed", "Failed", "Cancelled", "Deduped"):
            print(f"  ...{status}", flush=True)
            continue
        print(f"Fabric job status: {status} ({job.get('startTimeUtc', '')} -> {job.get('endTimeUtc', '')})")
        # Fabric marks a run Failed on dbt warnings too, so use dbt's own summary when available.
        summary = dbt_log_summary(cfg, run_id)
        if summary:
            d = summary["done"]
            print(f"dbt: PASS={d['pass']} WARN={d['warn']} ERROR={d['error']} SKIP={d['skip']}")
            print("\n".join(summary["problems"]))
            return d["error"] == 0
        if job.get("failureReason"):
            print(f"  reason: {job['failureReason'].get('message')}")
        return status == "Completed"
    print("Timed out waiting for the dbt job")
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", default="dev", choices=["dev", "prod"])
    parser.add_argument("--operation", default="build", choices=["build", "run", "test", "seed", "compile", "snapshot"])
    parser.add_argument("--select", default="", help="applies to this invocation only; empty = whole project")
    parser.add_argument("--exclude", default="")
    parser.add_argument("--threads", type=int)
    parser.add_argument("--skip-upload", action="store_true")
    parser.add_argument("--run", action="store_true", help="trigger the job after uploading and wait for the result")
    args = parser.parse_args()

    cfg = json.loads((REPO / "infra" / "config.json").read_text())[args.env]
    if not (DBT_DIR / "dbt_packages").exists():
        print("dbt_packages/ missing - run `dbt deps` in dbt/ first", file=sys.stderr)
        return 1

    content = get_content(cfg)
    if "connectionSettings" not in content.get("profile", {}):
        print("The job has no Warehouse connection. In Fabric: dbt job > dbt configurations > wh_gold > Apply.",
              file=sys.stderr)
        return 1

    if not args.skip_upload:
        ws, lh, folder = project_location(content)
        n, removed = mirror(ws, lh, folder)
        print(f"Mirrored {n} files to Lakehouse {lh} /{folder} ({removed} stale files removed)")

    command = content.setdefault("command", {"operation": "build", "arguments": {}})
    # operation, select and exclude are set on every invocation so a selection never carries over to later runs
    wanted = dict(command)
    wanted["arguments"] = dict(command.get("arguments", {}))
    wanted["operation"] = args.operation
    if args.select:
        wanted["arguments"]["select"] = args.select
    else:
        wanted["arguments"].pop("select", None)
    wanted["arguments"]["exclude"] = args.exclude
    for key, value in (("threads", args.threads),):
        if value is not None:
            wanted["arguments"][key] = value
    if wanted != command:
        content["command"] = wanted
        put_content(cfg, content)
        print(f"Job command updated: dbt {wanted['operation']} {wanted['arguments']}")

    if args.run:
        return 0 if run_job(cfg) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
