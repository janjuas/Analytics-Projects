# Target star schema (gold, `wh_gold.marts`)

Status: the full star schema is built and tested (✅): 8 dimensions, 5 facts, 2 seeds. Analysis marts are next.

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
| `fct_sales_line` ✅ | product line in a basket (2.6M) | quantity, shelf / sales / customer-paid value, loyalty / coupon / coupon-match discounts, unit prices | Incremental (`delete+insert`). Price logic follows the user guide's worked examples, covered by a unit test. |
| `fct_basket` ✅ | basket (276k trips) | lines, items, values, loyalty discount share, coupon used | Aggregate of `fct_sales_line`; reconciles to it in a test. |
| `fct_promo_exposure_weekly` ✅ | product × store × week (38.6M) | display / mailer codes and flags, units, sales and shelf value, baskets | 115 tracked stores, weeks 9–101. Promoted weeks from `causal_data` plus non-promoted sales weeks as the baseline. |
| `fct_campaign_targeting` ✅ | household × campaign (7,208) | coupons redeemed, sales during vs. equal window before | `is_window_complete` flags campaigns running past the last transaction day. |
| `fct_coupon_redemption` ✅ | redemption (2,318) | coupon discount on matched same-day lines | Lines matched through the coupon's eligible products. |

Supporting dimension: `dim_week` ✅ (103 weeks, with `is_promo_tracked_week`) for the weekly fact.

## Marts (analytics questions to answer)

- **Promotion uplift:** weekly unit sales when a product is on display or in the mailer vs. when it isn't, by department.
- **Price elasticity / discount depth:** sales response to `retail_discount` depth by commodity.
- **Campaign ROI:** response rate and incremental spend of targeted vs. non-targeted households, by campaign type.
- **Demographic segments (CACI angle):** spend, basket size and promo sensitivity by income band × household composition.
- **Private label share:** private vs. national share by department over time.

## Tests in place

- Model contracts on every dimension and fact.
- `relationships` from every fact key to its dimension, including seed-backed display and mailer codes.
- Singular tests: no calendar gaps, no household dropped, campaign end ≥ start, `fct_sales_line` reconciles to staging (rows and value), basket totals reconcile to lines.
- Unit test `sales_line_prices_match_user_guide_examples`: the guide's three receipt lines plus a quantity-0 line.
