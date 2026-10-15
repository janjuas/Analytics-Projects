{#
  Do deeper loyalty discounts sell more units per line, and in which commodities?
  Grain: one row per department x commodity x discount_depth_band (merchandise only; some commodity
  names, e.g. catch-all ones, appear under more than one department).
  Depth = loyalty discount / shelf value. Bands: 'No discount' (0) | '1-10%' (>0, <10%) | '10-20%' |
  '20-30%' | '30%+', lower bound inclusive.
#}

with lines as (
    select
        p.department,
        p.commodity,
        f.quantity,
        f.shelf_unit_price,
        f.paid_unit_price,
        f.loyalty_discount_value / f.shelf_value as depth
    from {{ ref('fct_sales_line') }} as f
    inner join {{ ref('dim_product') }} as p
        on f.product_sk = p.product_sk
    where p.is_merchandise = 1
      and f.quantity > 0                   -- refunds and corrections have no meaningful depth
      and f.shelf_value > 0
      and f.loyalty_discount_value >= 0    -- the few positive retail discounts give a negative depth
),

banded as (
    select
        *,
        case
            when depth = 0    then 'No discount'
            when depth < 0.10 then '1-10%'
            when depth < 0.20 then '10-20%'
            when depth < 0.30 then '20-30%'
            else '30%+'
        end as discount_depth_band,
        case
            when depth = 0    then 0
            when depth < 0.10 then 1
            when depth < 0.20 then 2
            when depth < 0.30 then 3
            else 4
        end as discount_depth_band_sort
    from lines
),

-- small commodities give noisy results; the threshold applies to the commodity total, not per band
eligible_commodities as (
    select department, commodity
    from banded
    group by department, commodity
    having count(*) >= 1000
),

aggregated as (
    select
        b.department,
        b.commodity,
        b.discount_depth_band,
        b.discount_depth_band_sort,
        count(*)                                  as lines,
        sum(b.quantity)                           as units,
        avg(cast(b.quantity as decimal(18, 4)))   as avg_units_per_line,
        avg(b.shelf_unit_price)                   as avg_shelf_unit_price,
        avg(b.paid_unit_price)                    as avg_paid_unit_price
    from banded as b
    inner join eligible_commodities as e
        on b.department = e.department
        and b.commodity = e.commodity
    group by b.department, b.commodity, b.discount_depth_band, b.discount_depth_band_sort
)

select
    cast(department as varchar(100))                     as department,
    cast(commodity as varchar(100))                      as commodity,
    cast(discount_depth_band as varchar(20))             as discount_depth_band,
    cast(discount_depth_band_sort as int)                as discount_depth_band_sort,
    cast(lines as int)                                   as lines,
    cast(units as int)                                   as units,
    cast(avg_units_per_line as decimal(12, 4))           as avg_units_per_line,
    cast(avg_shelf_unit_price as decimal(12, 4))         as avg_shelf_unit_price,
    cast(avg_paid_unit_price as decimal(12, 4))          as avg_paid_unit_price,
    cast(
        cast(units as decimal(18, 4)) / nullif(sum(units) over (partition by department, commodity), 0)
        as decimal(9, 4)
    )                                                    as units_share_of_commodity
from aggregated
