# Target star schema (gold, `wh_gold.marts`)

Status: all dimensions are built and tested (✅). Facts are planned, listed in build order.

## Dimensions

| Model | Grain | Built from | Notes |
|---|---|---|---|
| `dim_date` ✅ | study day (1–719) | numbers CTE, bounded by transactions, campaigns and redemptions | Day 1 anchored on a Wednesday so source weeks (starting day 6) run Monday–Sunday. `study_year`, `is_in_transaction_window`. |
| `dim_product` ✅ | product_id | `stg_silver__products` | National vs private label, department > commodity > sub-commodity hierarchy. |
| `dim_household` ✅ | household (all 2,500) | transactions, left-joined to demographics | 1,699 households without demographics keep `Unknown` bands and `has_demographics = 0`. Ordinal `*_sort` columns for reporting. |
| `dim_campaign` ✅ | campaign_id (30) | campaigns, targeting, coupon pool, `dim_date` | Type A/B/C with descriptions from the user guide, start/end dates, households targeted, coupon pool size. |
| `dim_store` ✅ | store_id (582) | transactions + causal | `has_promo_tracking` (115 stores) and a panel-spend tercile; the source has no store attributes. |
| `dim_display_location` ✅ | display code | seed `display_location_codes` | Display location descriptions from the user guide. |
| `dim_mailer_location` ✅ | mailer code | seed `mailer_location_codes` | Mailer placement descriptions from the user guide. |

## Facts

| Model | Grain | Key measures | Notes |
|---|---|---|---|
| `fct_sales_line` | one product line in a basket | quantity, sales_value, retail_discount, coupon_discount, coupon_match_discount, derived shelf price | Large: materialise `incremental` on `day_number` to practise incremental models. |
| `fct_basket` | basket_id | basket value, items, discount depth, coupon used | Aggregate of `fct_sales_line`. Good for basket-mix questions. |
| `fct_promo_exposure_weekly` | product × store × week | is_on_display, is_in_mailer, display_code, mailer_code | From `stg_silver__causal`. Join to weekly sales to measure promotion uplift. |
| `fct_campaign_targeting` | household × campaign | targeted flag, redeemed flag, redemptions | Fact without measures + redemptions. Gives campaign response rates. |
| `fct_coupon_redemption` | household × coupon × day | 1 per redemption | Join back to `fct_sales_line` on household + day for redeemed value. |

## Marts (analytics questions to answer)

- **Promotion uplift:** weekly unit sales when a product is on display or in the mailer vs. when it isn't, by department.
- **Price elasticity / discount depth:** sales response to `retail_discount` depth by commodity.
- **Campaign ROI:** response rate and incremental spend of targeted vs. non-targeted households, by campaign type.
- **Demographic segments (CACI angle):** spend, basket size and promo sensitivity by income band × household composition.
- **Private label share:** private vs. national share by department over time.

## Planned tests

- `relationships` from every fact FK to its dimension.
- `dbt_utils.expression_is_true`: basket totals equal the sum of their lines; discounts are ≤ 0.
- `dbt_utils.recency` / row-count checks between silver and gold (`dbt_utils.equal_rowcount`).
- Model contracts (`contract: enforced: true`) on every published mart, as on `dim_product`.
- At least one **unit test** (`unit_tests:` in YAML, dbt ≥1.8) on a derived metric such as shelf price.
