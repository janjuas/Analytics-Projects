{#
  QUESTION   How do spend, basket size and promotion sensitivity differ by income x household composition?

  GRAIN      One row per income_band x household_composition, plus one row for households without
             demographics ('Unknown' x 'Unknown') as a comparison group.

  INPUTS     ref('dim_household')   income_band, household_composition, *_sort, has_demographics
             ref('fct_basket')      basket-level sales_value, shelf_value, loyalty_discount_value, has_coupon

  OUTPUT     income_band, income_band_sort, household_composition, household_composition_sort,
             households, baskets, baskets_per_household, avg_basket_value, sales_per_household,
             loyalty_discount_share, coupon_basket_share, is_small_segment

  DEFINITIONS
             loyalty_discount_share = sum(loyalty_discount_value) / sum(shelf_value)   (promo sensitivity)
             coupon_basket_share    = share of baskets with has_coupon = 1
             is_small_segment       = 1 when households < 10 (62 segments, several are tiny)

  TRAPS
  1. Aggregate baskets to household first, then to segment, so per-household figures are not
     weighted by heavy shoppers.
  2. Don't drop the 1,699 households without demographics; they form the 'Unknown' comparison row.
  3. Carry the *_sort columns through so Power BI orders Level1..Level12 correctly.

  WHEN DONE  Delete the config line below, then:
             python infra/sync_dbt_job.py --run --select household_segment_summary
#}
{{ config(enabled=false) }}

with household_totals as (
    -- TODO: per household_sk from fct_basket: baskets, sales, shelf value, loyalty discount, coupon baskets
    select 1 as placeholder
),

households as (
    -- TODO: dim_household joined to household_totals (trap 2)
    select * from household_totals
)

-- TODO: aggregate to income_band x household_composition (trap 1), add ratios and is_small_segment,
--       keep the sort columns (trap 3)
select * from households
