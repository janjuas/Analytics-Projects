"""Upload the raw dunnhumby CSVs into the bronze Lakehouse (Files/raw/<table>/<file>.csv) via OneLake.

Auth uses your `az login` session. Re-running overwrites files, so it is safe to repeat.

    python infra/upload_raw.py --source "<folder with the CSVs>" [--env dev]
"""
import argparse
import json
import pathlib
import sys

from azure.identity import AzureCliCredential
from azure.storage.filedatalake import DataLakeServiceClient

ONELAKE_URL = "https://onelake.dfs.fabric.microsoft.com"
CONFIG = pathlib.Path(__file__).with_name("config.json")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, help="Folder containing the dunnhumby CSV files")
    parser.add_argument("--env", default="dev", choices=["dev", "prod"])
    args = parser.parse_args()

    cfg = json.loads(CONFIG.read_text())[args.env]
    source = pathlib.Path(args.source)
    files = sorted(source.glob("*.csv"))
    if not files:
        print(f"No CSV files found in {source}", file=sys.stderr)
        return 1

    service = DataLakeServiceClient(ONELAKE_URL, credential=AzureCliCredential())
    fs = service.get_file_system_client(cfg["workspace_id"])
    root = f"{cfg['lh_bronze_id']}/Files/raw"

    for f in files:
        table = f.stem.lower()
        target = f"{root}/{table}/{f.name}"
        size_mb = f.stat().st_size / 1_048_576
        print(f"Uploading {f.name} ({size_mb:,.1f} MB) -> Files/raw/{table}/", flush=True)
        with f.open("rb") as data:
            fs.get_file_client(target).upload_data(
                data, overwrite=True, chunk_size=8 * 1_048_576, max_concurrency=8
            )
    print(f"Done: {len(files)} files uploaded to lh_bronze/Files/raw")
    return 0


if __name__ == "__main__":
    sys.exit(main())
