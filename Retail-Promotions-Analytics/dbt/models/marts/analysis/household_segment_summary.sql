{#
  How do spend, basket size and promotion sensitivity differ by income x household composition?
  Grain: one row per income_band x household_composition. Households without demographics fall into a
  single 'Unknown' x 'Unknown' row, kept as a comparison group.
  Baskets are summed per household first, so per-household figures are not weighted by heavy shoppers.
#}

with household_totals as (
    select
        household_sk,
        count(*)                    as baskets,
        sum(sales_value)            as sales_value,
        sum(shelf_value)            as shelf_value,
        sum(loyalty_discount_value) as loyalty_discount_value,
        sum(has_coupon)             as coupon_baskets
    from {{ ref('fct_basket') }}
    group by household_sk
),

households as (
    select
        h.income_band,
        h.income_band_sort,
        h.household_composition,
        h.household_composition_sort,
        t.baskets,
        t.sales_value,
        t.shelf_value,
        t.loyalty_discount_value,
        t.coupon_baskets,
        t.sales_value / nullif(t.baskets, 0) as household_avg_basket_value
    from {{ ref('dim_household') }} as h
    inner join household_totals as t
        on h.household_sk = t.household_sk
)

select
    cast(income_band as varchar(50))                                                     as income_band,
    cast(income_band_sort as int)                                                        as income_band_sort,
    cast(household_composition as varchar(50))                                          as household_composition,
    cast(household_composition_sort as int)                                              as household_composition_sort,
    cast(count(*) as int)                                                                as households,
    cast(sum(baskets) as int)                                                            as baskets,
    cast(avg(cast(baskets as decimal(18, 4))) as decimal(12, 2))                         as baskets_per_household,
    cast(avg(household_avg_basket_value) as decimal(12, 2))                              as avg_basket_value,
    cast(avg(sales_value) as decimal(14, 2))                                             as sales_per_household,
    cast(sum(loyalty_discount_value) / nullif(sum(shelf_value), 0) as decimal(9, 4))     as loyalty_discount_share,
    cast(sum(cast(coupon_baskets as decimal(18, 4))) / nullif(sum(baskets), 0) as decimal(9, 4))
                                                                                         as coupon_basket_share,
    cast(case when count(*) < 10 then 1 else 0 end as int)                               as is_small_segment
from households
group by income_band, income_band_sort, household_composition, household_composition_sort
