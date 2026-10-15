# Target star schema (gold, `wh_gold.marts`)

`dim_product` is built as a worked example. Everything else below is the design to build next, in roughly this order.

## Dimensions

| Model | Grain | Built from | Notes |
|---|---|---|---|
| `dim_date` | one row per study day (1–711) | generated (`dbt_utils.date_spine` or a numbers CTE) | `day_number`, `week_number`, a calendar date anchored on `var('day_one_date')`, day of week, month, is_weekend. The source has only day numbers. |
| `dim_product` ✅ | product_id | `stg_silver__products` | National vs private label, department > commodity > sub-commodity hierarchy. |
| `dim_household` | household_key (all 2,500) | transactions ∪ demographics | Left-join demographics so the 1,699 households without them get `'Unknown'` bands rather than dropping out. `has_demographics` flag. This is where the CACI-style segmentation questions live. |
| `dim_campaign` | campaign_id | `stg_silver__campaigns` | Type A/B/C, start/end day, duration, households targeted. |
| `dim_store` | store_id | distinct stores in transactions + causal | No store attributes in the source. Derive size bands from sales. |

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

## Tests to add as you go

- `relationships` from every fact FK to its dimension.
- `dbt_utils.expression_is_true`: basket totals equal the sum of their lines; discounts are ≤ 0.
- `dbt_utils.recency` / row-count checks between silver and gold (`dbt_utils.equal_rowcount`).
- Model contracts (`contract: enforced: true`) on every published mart, as on `dim_product`.
- At least one **unit test** (`unit_tests:` in YAML, dbt ≥1.8) on a derived metric such as shelf price.
