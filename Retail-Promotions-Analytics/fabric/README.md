# Fabric workspace items (Git-synced)

This folder is connected to the `dunnhumby-promo-dev` Fabric workspace through Fabric Git integration
(branch `main`). Fabric writes it, so don't edit item files by hand. Change them in the workspace and commit
from its **Source control** panel, or edit on a branch and use **Update all** after merging.

| Item | Type | Purpose |
|---|---|---|
| `lh_bronze` | Lakehouse | raw CSVs (`Files/raw`) and as-landed `raw_*` Delta tables |
| `lh_silver` | Lakehouse | typed, cleaned tables (dbt sources), plus the dbt project files the dbt job reads (`Files/dbt`) |
| `wh_gold` | Warehouse | dbt-built star schema (`staging`, `marts`) |
| `nb_01_bronze_ingest` | Notebook | CSV → `raw_*` Delta |
| `nb_02_silver_clean` | Notebook | `raw_*` → typed silver, duplicate-key resolution, `_rejects` |
| `dbt_promo_star_schema` | dbt job | runs `../dbt` (published to `lh_silver/Files/dbt`) against `wh_gold` |
| `Retail Promotions` | Semantic model | Direct Lake model over `wh_gold` marts and analysis tables |
| `Retail Promotions Analysis` | Report | 5-page report on the semantic model |
