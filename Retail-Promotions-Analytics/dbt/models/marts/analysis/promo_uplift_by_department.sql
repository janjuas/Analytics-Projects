{#
  QUESTION   How much more does a product sell in a store in weeks it is on display / in the mailer,
             compared with weeks it is not promoted, by department?

  GRAIN      One row per department x promo_type.
             promo_type: 'Display only' | 'Mailer only' | 'Display + mailer'

  INPUTS     ref('fct_promo_exposure_weekly')   product x store x week, is_on_display, is_in_mailer, units_sold
             ref('dim_product')                 department

  OUTPUT     department, promo_type, product_store_pairs, promoted_weeks, baseline_weeks,
             avg_units_promoted, avg_units_baseline, uplift_pct

  TRAPS
  1. Asymmetric zeros. Promoted weeks exist even when nothing sold (36M rows with units_sold = 0), but
     non-promoted weeks only exist when something sold. Comparing averages directly compares
     "promoted incl. zeros" with "baseline excl. zeros" and understates uplift.
     Fair comparison: keep only weeks with units_sold > 0 on BOTH sides (average units in weeks the
     product sold). Say so in the column description.
  2. Like-for-like. Only compare product-store pairs that have at least one promoted AND one baseline
     week of this promo type; otherwise you compare different products.
  3. Average per pair first, then across pairs, so one high-volume product doesn't dominate.
  4. Use cast(... as decimal(18, 4)) before dividing; integer / integer truncates in T-SQL.

  WHEN DONE  Delete the config line below, then:
             python infra/sync_dbt_job.py --run --select promo_uplift_by_department
#}
{{ config(enabled=false) }}

with weekly as (
    -- TODO: select from fct_promo_exposure_weekly, join dim_product for department,
    --       keep weeks with units_sold > 0 (trap 1)
    select 1 as placeholder
),

classified as (
    -- TODO: promo_type = 'Display only' / 'Mailer only' / 'Display + mailer' / 'None' from the two flags
    select * from weekly
),

pair_level as (
    -- TODO: per department, product_sk, store_sk, promo_type: count weeks and average units.
    --       The baseline ('None') rows have to be lined up against each promo_type for the same pair.
    --       Hint: build pair baselines in their own CTE, then join promoted pair rows to it.
    select * from classified
),

like_for_like as (
    -- TODO: keep only pairs that have both a promoted and a baseline average (trap 2)
    select * from pair_level
)

-- TODO: aggregate to department x promo_type (trap 3), compute
--       uplift_pct = avg_units_promoted / avg_units_baseline - 1
select * from like_for_like
