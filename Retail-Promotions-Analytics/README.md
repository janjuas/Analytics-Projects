# Retail promotions analytics — dunnhumby "The Complete Journey" on Microsoft Fabric + dbt

Two years of grocery transactions for 2,500 households, along with product, demographic, campaign, coupon and weekly
in-store promotion data. The raw files land in a Fabric Lakehouse (bronze), Spark cleans them (silver), and dbt models
a tested, documented star schema in a Fabric Warehouse (gold). Every change goes through GitHub pull requests, and a
Fabric deployment pipeline promotes items from dev to prod.

```
 CSV files ──► lh_bronze ──────────────► lh_silver ───────────────► wh_gold (dbt)
 (OneLake)     Files/raw + raw_* Delta    typed, cleaned, deduped    staging (views) ─► marts (tables)
               nb_01_bronze_ingest        nb_02_silver_clean         tests · docs · contracts
                                          _rejects (with reason)

 GitHub (PRs, dbt CI) ◄──► dunnhumby-promo-dev ──[deployment pipeline]──► dunnhumby-promo-prod
```

## What exists

| Resource | Name | ID |
|---|---|---|
| Capacity | Trial (FTL64, UK South) | `6315ea76-3056-4f91-8209-24c0a6ad0e00` |
| Workspace (dev) | `dunnhumby-promo-dev` | `b012dc67-8617-4001-9e2c-87ca2d1c24ca` |
| Workspace (prod) | `dunnhumby-promo-prod` | `9da73741-81f4-4edc-a1c0-33045a507804` |
| Lakehouse | `lh_bronze` | `960dce80-36fe-42f9-9e94-c092c07e0f4a` |
| Lakehouse | `lh_silver` | `aba1354d-6905-47e8-852a-366ad2745478` |
| Warehouse | `wh_gold` | `f2e91e90-11a1-4eed-8d5d-b2c59e034c22` |
| Notebook | `nb_01_bronze_ingest` | `34d77549-2c09-4864-bdee-d1cd16898462` |
| Notebook | `nb_02_silver_clean` | `891a9c48-45c0-412f-a049-4f812b5e1a17` |
| dbt job | `dbt_promo_star_schema` (project: `lh_silver/Files/dbt`, target: `wh_gold`) | `7c1b6a07-ed63-4da8-b1db-8af767a994e6` |
| Deployment pipeline | `dunnhumby-promo` (Development → Production) | `d8db794c-f708-49c4-b9e9-a0585bf5ca7a` |

Dev SQL endpoint (Warehouse and both Lakehouses): `63lxcuql4fvu7iqtjpgd6no5fq-m7obfmaxqyaubhrmq7fc2hbezi.datawarehouse.fabric.microsoft.com`

## Repo layout

This project is the `Retail-Promotions-Analytics/` folder of
[janjuas/Analytics-Projects](https://github.com/janjuas/Analytics-Projects). All paths below are relative to that folder,
except the CI workflow, which GitHub requires at the repo root.

```
dbt/                 dbt project (dbt-fabric). profiles.yml is committed and holds no secrets.
  models/staging/    1:1 views over lh_silver, renamed, with tests
  models/marts/      star schema (dim_product built; roadmap in docs/star_schema.md)
fabric/              Fabric workspace items, synced by Git integration: notebooks, lakehouses, warehouse, dbt job
infra/               IDs + scripts: upload_raw.py, sync_dbt_job.py, create_deployment_pipeline.sh, connect_git.sh
docs/star_schema.md  target model design, planned analyses and tests
../.github/workflows/retail-promotions-dbt.yml   CI: parse on every PR; on merge, publish to Fabric and run the dbt job
```

## Local setup

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
az login                                   # the dbt dev target authenticates with the Azure CLI session
```

Running dbt locally also needs **Microsoft ODBC Driver 18 for SQL Server**:

```bash
winget install --id Microsoft.msodbcsql.18 -e
```

Then:

```bash
cd dbt
../.venv/Scripts/dbt deps --profiles-dir .
../.venv/Scripts/dbt debug --profiles-dir .
../.venv/Scripts/dbt build --profiles-dir .          # runs models + tests
../.venv/Scripts/dbt docs generate --profiles-dir . && ../.venv/Scripts/dbt docs serve --profiles-dir .
```

## Running dbt inside Fabric (dbt job)

The Fabric **dbt job** `dbt_promo_star_schema` runs this project on Fabric's managed dbt runtime, so nothing has to
be installed to build gold. The runtime uses dbt-core 1.11 and dbt-fabric 1.10, slightly older than the local
1.12 / 1.11.

| Setting | Lives in | Set by |
|---|---|---|
| Project files | `lh_silver` → `Files/dbt` (job setting: project type `Lakehouse`, folder `dbt`) | `infra/sync_dbt_job.py` (locally, or from CI on merge to `main`) |
| Target profile (`wh_gold`, schema `Gold_DH`) | job's **dbt configurations** | Fabric UI. The **connection** field there is the *target* dbt builds into, so it must stay `wh_gold`. |
| Command (`build` / `run` / `test`, select, exclude, threads) | job definition | `sync_dbt_job.py --operation/--select/...` or the UI |
| Schedule | job's **Schedule** tab | Fabric UI |

Runtime notes:
- **Fabric marks a run "Failed" when dbt reports any warning**, even with `ERROR=0`. `sync_dbt_job.py --run` reads the run's `Output/<run id>/logs/dbt.log` and passes or fails on dbt's own `Done.` summary instead.
- **No `persist_docs`**: Fabric Warehouse has no table or column comments, so it errors with `alter_column_comment macro not implemented`.
- **Dot-folders break the project download.** The script skips them and uploads only the macros of `dbt_packages/`.
- Each run's compiled SQL and `dbt.log` are kept in the job's OneLake storage under `Output/<run id>/`.

```bash
.venv/Scripts/python infra/sync_dbt_job.py          # publish dbt/ to the Lakehouse folder
.venv/Scripts/python infra/sync_dbt_job.py --run    # publish, run the job in Fabric, wait, exit 1 on failure
.venv/Scripts/python infra/sync_dbt_job.py --run --select campaign_effect   # build and test one model
```

`--select` applies to that run only; the next run without it builds the whole project again.

Models still build into `staging` and `marts` because of `macros/generate_schema_name.sql`. The profile schema
(`Gold_DH`) is only used for anything without a custom schema.

The project is published to a Lakehouse folder rather than edited inside the job, so CI can update it on every
merge and Git stays the single source of truth.

## Re-loading data

```bash
.venv/Scripts/python infra/upload_raw.py --source "<folder with the CSVs>"
```
Then run `nb_01_bronze_ingest` and `nb_02_silver_clean` in the dev workspace (both have a `tables` parameter for partial reloads).

## GitHub integration (set-up)

1. Turn on the tenant setting **Users can sync workspace items with GitHub repositories** (Admin portal → Tenant settings → Git integration). `Retail-Promotions-Analytics/fabric` must exist on `main` in `janjuas/Analytics-Projects`.
2. Create a fine-grained PAT scoped to `Analytics-Projects` with **Contents: Read and write**.
3. In Fabric go to **Settings → Manage connections and gateways → New → Cloud → GitHub - Source control**, paste the PAT and save. Copy the connection ID.
4. Run `bash infra/connect_git.sh <connection-id>`. This connects `dunnhumby-promo-dev` to `main:/Retail-Promotions-Analytics/fabric` and commits the workspace items.
5. On GitHub, protect `main`: **Settings → Branches → Add rule** → require a pull request, and require the `parse` status check from the *Retail Promotions - dbt* workflow.

Day-to-day work: branch, change dbt or notebooks, open a PR, CI parses it, merge, then click **Update all** in the dev workspace's Source control panel.

## Promote to prod

Open the `dunnhumby-promo` deployment pipeline and click **Deploy** from Development to Production. This copies the
notebooks, the Lakehouse definitions and the Warehouse schema, but **not data**. After deploying:

1. Upload the raw files to prod (`upload_raw.py --env prod` once you have added the prod `lh_bronze_id` to `infra/config.json`), then run both notebooks in prod. They find their Lakehouses by name, so they work without edits.
2. In the prod copy of `dbt_promo_star_schema`, open **dbt configurations** and point the profile at the **prod** `wh_gold` and the project source at the **prod** `lh_silver` → `Files/dbt`. Deployment rules don't cover dbt jobs yet, so check that it doesn't still point at dev. Add the prod job's ID (`dbt_job_id`) to `infra/config.json`, then run `sync_dbt_job.py --env prod --run`, or the CI workflow manually with `env: prod`.

## CI (GitHub Actions)

- **Every PR:** `dbt parse`. Needs no credentials.
- **Merge to `main`:** publishes `dbt/` to `lh_silver/Files/dbt`, runs the Fabric dbt job (`dbt build`) and fails the workflow if any model or test fails.
- **Manual run:** the same as a merge, for `dev` or `prod`, with a choice of dbt command.

The merge and manual jobs need a service principal:

1. Entra ID → App registrations → new app → create a client secret.
2. Fabric admin portal → Tenant settings → turn on **Service principals can use Fabric APIs**.
3. Add the app as **Contributor** on both workspaces. That covers writing the Lakehouse files and starting the job. The job itself still connects to the Warehouse with the OAuth connection saved in the UI.
4. GitHub repo → Settings → Secrets: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`. Variable: `FABRIC_CI_ENABLED=true`. Environments: `development` and `production`; add required reviewers on `production` for a manual gate.

Running dbt locally against `wh_gold` (`dbt build` with `profiles.yml`) still works and needs ODBC Driver 18, see Local setup.

## Data quality notes

- **`hh_demographic` headers are anonymised** in this copy: `classification_1..5`. Silver gives them descriptive names inferred from the original public release of this dataset, whose value sets match: 1 = age, 2 = marital status (X/Y/Z), 3 = income (Level1–12), 4 = household size, 5 = household composition. The bundled user guide only describes them as ordinal segments, and the band values stay anonymised.
- **Demographics cover only 801 of the 2,500 households.** Household analysis keeps the other 1,699 as `Unknown` rather than dropping them.
- **`causal_data` has 15,245 product/store/week keys that appear twice with conflicting display/mailer codes** (0.04%). Silver keeps the row showing the most promotion exposure and writes the other to `lh_silver._rejects` with `reason = 'duplicate_key'`.
- **Time is relative:** `DAY` 1–711 and `WEEK_NO` 1–102 have no calendar dates. Day 1 is anchored to a calendar date through `var('day_one_date')`.
- Discounts (`RETAIL_DISC`, `COUPON_DISC`, `COUPON_MATCH_DISC`) are stored as zero or negative numbers, except for **10 lines with a positive `RETAIL_DISC`**. Most are quantity-0 lines where the discount equals the sales value, which look like refunds or price corrections. The `accepted_range` test warns on them and fails only if there are more than 50.
