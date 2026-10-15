{#
  QUESTION   Do deeper loyalty discounts sell more units per line, and in which commodities?

  GRAIN      One row per commodity x discount_depth_band.

  INPUTS     ref('fct_sales_line')   loyalty_discount_value, shelf_value, quantity, shelf_unit_price, paid_unit_price
             ref('dim_product')      department, commodity

  OUTPUT     department, commodity, discount_depth_band, discount_depth_band_sort, lines, units,
             avg_units_per_line, avg_shelf_unit_price, avg_paid_unit_price, units_share_of_commodity

  BANDS      depth = loyalty_discount_value / shelf_value
             'No discount' (0) | '1-10%' | '10-20%' | '20-30%' | '30%+'     sort 0..4

  TRAPS
  1. Exclude lines with quantity = 0 or shelf_value <= 0 (refunds / corrections; depth is meaningless).
  2. ~10 lines have a positive retail discount, which gives a negative depth. Exclude depth < 0.
  3. Band boundaries: decide whether 10% falls in '1-10%' or '10-20%' and be consistent (use >= / <).
  4. Small commodities give noisy results. Keep commodities with at least 1,000 lines in total
     (filter on the commodity total, not per band).
  5. units_share_of_commodity needs a window: sum(units) over (partition by commodity).

  WHEN DONE  Delete the config line below, then:
             python infra/sync_dbt_job.py --run --select discount_depth_response
#}
{{ config(enabled=false) }}

with lines as (
    -- TODO: fct_sales_line joined to dim_product; apply traps 1 and 2; compute depth
    select 1 as placeholder
),

banded as (
    -- TODO: discount_depth_band and discount_depth_band_sort from depth (trap 3)
    select * from lines
),

eligible_commodities as (
    -- TODO: commodities with >= 1,000 lines in total (trap 4)
    select * from banded
)

-- TODO: aggregate to commodity x band; add units_share_of_commodity (trap 5)
select * from eligible_commodities
