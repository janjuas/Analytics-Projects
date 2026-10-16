# Technical guide

How the Retail Promotions Analytics project is built and run. For the findings, see the
[project overview](../README.md).

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
| Semantic model | `Retail Promotions` (Direct Lake on the `wh_gold` SQL endpoint) | `1eecc8d6-15dd-4bbb-b842-e06faf4996d1` |
| Report | `Retail Promotions Analysis` (5 pages) | `102e25f6-04fb-4fbf-ae4c-98ccd248cf06` |
| Deployment pipeline | `dunnhumby-promo` (Development → Production) | `d8db794c-f708-49c4-b9e9-a0585bf5ca7a` |

Dev SQL endpoint (Warehouse and both Lakehouses): `63lxcuql4fvu7iqtjpgd6no5fq-m7obfmaxqyaubhrmq7fc2hbezi.datawarehouse.fabric.microsoft.com`

## Repo layout

This project is the `Retail-Promotions-Analytics/` folder of
[janjuas/Analytics-Projects](https://github.com/janjuas/Analytics-Projects). All paths in this guide are relative to
that folder, except the CI workflow, which GitHub requires at the repo root.

```
dbt/                 dbt project (dbt-fabric). profiles.yml is committed and holds no secrets.
  models/staging/    1:1 views over lh_silver, renamed, with tests
  models/marts/      core/ star schema (8 dimensions, 5 facts) and analysis/ marts behind the report
fabric/              Fabric workspace items, synced by Git integration: notebooks, lakehouses, warehouse, dbt job
infra/               IDs + scripts: upload_raw.py, sync_dbt_job.py, create_deployment_pipeline.sh, connect_git.sh
powerbi-desktop/     Import-mode copy of the report for Power BI Desktop (see Power BI report)
docs/star_schema.md  model design, analysis marts and tests
docs/technical_guide.md   this guide
README.md            project overview and findings
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

## Power BI report

`Retail Promotions Analysis` is a thin report on the `Retail Promotions` semantic model, which reads `wh_gold`
in **Direct Lake on SQL** mode through the Warehouse's SQL endpoint (no import or scheduled refresh; it reads the
Warehouse's Delta tables directly).
Both are in `fabric/` and versioned through Fabric Git integration.

**Model:** 18 tables (5 facts, 8 dimensions, 5 analysis tables), 19 single-direction relationships, 42 measures
with formats, descriptions and display folders. Keys, sort columns and raw numeric columns are hidden behind
measures. `Date` is the marked date table and filters `Week`, so one week slicer filters daily and weekly facts.

| Page | Question it answers | Main visuals |
|---|---|---|
| Overview | Headline performance | 6 KPIs, weekly sales, top 10 departments |
| Promotions | Which mechanic earns its place, and where | Uplift by mechanic; department x mechanic matrix (cells with 100+ product-store pairs) |
| Discounts and Private Label | Are discounts deep enough; is own-label growing | Units per line by depth band; private-label share year 1 vs 2 |
| Campaigns | Did campaigns lift spend against comparable households | Matched vs unmatched lift by campaign type; campaign detail |
| Customers | Which segments are most valuable and promotion-sensitive | Sales per household matrix (income x composition); coupon use by income |

Each page states its main caveat in the subtitle. Product-level pages are filtered to merchandise. Currency
measures are formatted in pounds (£).

### Power BI Desktop version

`powerbi-desktop/Retail Analysis.pbip` is the same five pages on a local **Import** model, for opening in
Power BI Desktop without the Fabric report. It reads `wh_gold` through the OneLake catalog (Fabric Warehouse
connector); the workspace and warehouse are the `WorkspaceId` and `WarehouseId` parameters, so pointing it at prod
is a parameter change.

- 14 tables: the ones the report uses. The 38.6M-row `fct_promo_exposure_weekly` is replaced by `Promotion Week`,
  which counts product-store-weeks per display code, mailer code and promoted flag (merchandise only). The
  Warehouse does that aggregation at refresh.
- To use it: open the `.pbip`, click **Refresh** and sign in with an organisational account that can read `wh_gold`.
  The data cache and user settings are not committed, so the first open is empty until refreshed.
- This version is published to the web as the public, read-only report linked from the project overview.

## Re-loading data

```bash
.venv/Scripts/python infra/upload_raw.py --source "<folder with the CSVs>"
```
Then run `nb_01_bronze_ingest` and `nb_02_silver_clean` in the dev workspace (both have a `tables` parameter for partial reloads).

## Git integration

The dev workspace `dunnhumby-promo-dev` is connected to `main:/Retail-Promotions-Analytics/fabric` through a Fabric
"GitHub - Source control" connection that uses a fine-grained token with **Contents: Read and write** on this repo.
`infra/connect_git.sh` makes that connection and the first commit. It needs the tenant setting **Users can sync
workspace items with GitHub repositories**. `main` requires a pull request and the `parse` check from the
*Retail Promotions - dbt* workflow.

Day-to-day work: branch, change dbt, notebooks or report files, open a PR, let CI parse it, merge, then click
**Update all** in the dev workspace's Source control panel.

## Promote to prod

The `dunnhumby-promo` deployment pipeline deploys from Development to Production. It copies the notebooks, the
Lakehouse definitions and the Warehouse schema, but **not data**. A first deployment to prod also needs:

1. Raw files in prod: `upload_raw.py --env prod`, with the prod `lh_bronze_id` in `infra/config.json`, then both
   notebooks run in prod. They find their Lakehouses by name, so they need no edits.
2. The prod copy of `dbt_promo_star_schema` pointed at the **prod** `wh_gold` (dbt configurations) and the **prod**
   `lh_silver` → `Files/dbt` (project source). Deployment rules don't cover dbt jobs, so these are set in the UI.
   With the prod job's ID as `dbt_job_id` in `infra/config.json`, `sync_dbt_job.py --env prod --run` (or the CI
   workflow run manually with `env: prod`) builds prod.

## CI (GitHub Actions)

- **Every PR:** `dbt parse`. Needs no credentials.
- **Merge to `main`:** publishes `dbt/` to `lh_silver/Files/dbt`, runs the Fabric dbt job (`dbt build`) and fails the workflow if any model or test fails.
- **Manual run:** the same as a merge, for `dev` or `prod`, with a choice of dbt command.

The merge and manual jobs run as a service principal. It needs the tenant setting **Service principals can use
Fabric APIs** and **Contributor** on both workspaces, which covers writing the Lakehouse files and starting the
job; the job itself connects to the Warehouse with the OAuth connection saved in its dbt configurations. The
workflow reads the secrets `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET` and only runs these jobs
when the repo variable `FABRIC_CI_ENABLED` is `true`. The `production` environment can carry required reviewers as
a manual gate.

## Data quality notes

- **`hh_demographic` headers are anonymised** in this copy: `classification_1..5`. Silver gives them descriptive names inferred from the original public release of this dataset, whose value sets match: 1 = age, 2 = marital status (X/Y/Z), 3 = income (Level1–12), 4 = household size, 5 = household composition. The bundled user guide only describes them as ordinal segments, and the band values stay anonymised. Income is the exception: `dim_household.income_band` shows the annual income range from the seed `income_band_ranges` (Under 15K to 250K+), the bands of the original release, matched level by level on household counts; the delivered level stays in `income_level`.
- **Demographics cover only 801 of the 2,500 households.** Household analysis keeps the other 1,699 as `Unknown` rather than dropping them.
- **`causal_data` has 15,245 product/store/week keys that appear twice with conflicting display/mailer codes** (0.04%). Silver keeps the row showing the most promotion exposure and writes the other to `lh_silver._rejects` with `reason = 'duplicate_key'`.
- **Time is relative:** `DAY` 1–711 and `WEEK_NO` 1–102 have no calendar dates. Day 1 is anchored to a calendar date through `var('day_one_date')`.
- Discounts (`RETAIL_DISC`, `COUPON_DISC`, `COUPON_MATCH_DISC`) are stored as zero or negative numbers, except for **10 lines with a positive `RETAIL_DISC`**. Most are quantity-0 lines where the discount equals the sales value, which look like refunds or price corrections. The `accepted_range` test warns on them and fails only if there are more than 50.
