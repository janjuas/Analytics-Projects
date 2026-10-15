{#
  How much more does a product sell in a store in weeks it is on display / in the mailer, compared with
  weeks it is not promoted, by department?
  Grain: one row per department x promo_type (merchandise only, 115 promo-tracked stores, weeks 9-101).

  Only weeks with sales are compared: promoted weeks are recorded even when nothing sold, but
  non-promoted weeks only exist when something sold, so including zeros on one side only would bias the
  result. The measure is therefore "units in a week the product sold". Comparisons are like-for-like
  (same product and store) and averaged per pair before averaging across pairs.
#}

with weekly as (
    select
        p.department,
        f.product_sk,
        f.store_sk,
        f.units_sold,
        case
            when f.is_on_display = 1 and f.is_in_mailer = 1 then 'Display + mailer'
            when f.is_on_display = 1                        then 'Display only'
            when f.is_in_mailer = 1                         then 'Mailer only'
            else 'None'
        end as promo_type
    from {{ ref('fct_promo_exposure_weekly') }} as f
    inner join {{ ref('dim_product') }} as p
        on f.product_sk = p.product_sk
    where p.is_merchandise = 1
      and f.units_sold > 0
),

pair_baseline as (
    select
        product_sk,
        store_sk,
        count(*)                                    as baseline_weeks,
        avg(cast(units_sold as decimal(18, 4)))     as avg_units_baseline
    from weekly
    where promo_type = 'None'
    group by product_sk, store_sk
),

pair_promoted as (
    select
        department,
        product_sk,
        store_sk,
        promo_type,
        count(*)                                    as promoted_weeks,
        avg(cast(units_sold as decimal(18, 4)))     as avg_units_promoted
    from weekly
    where promo_type <> 'None'
    group by department, product_sk, store_sk, promo_type
),

-- only pairs with both a promoted and a baseline week of their own
like_for_like as (
    select
        pr.department,
        pr.promo_type,
        pr.promoted_weeks,
        b.baseline_weeks,
        pr.avg_units_promoted,
        b.avg_units_baseline
    from pair_promoted as pr
    inner join pair_baseline as b
        on pr.product_sk = b.product_sk
        and pr.store_sk = b.store_sk
)

select
    cast(department as varchar(100))                                               as department,
    cast(promo_type as varchar(20))                                                as promo_type,
    cast(count(*) as int)                                                          as product_store_pairs,
    cast(sum(promoted_weeks) as int)                                               as promoted_weeks,
    cast(sum(baseline_weeks) as int)                                               as baseline_weeks,
    cast(avg(avg_units_promoted) as decimal(12, 4))                                as avg_units_promoted,
    cast(avg(avg_units_baseline) as decimal(12, 4))                                as avg_units_baseline,
    cast(avg(avg_units_promoted) / nullif(avg(avg_units_baseline), 0) - 1 as decimal(9, 4))
                                                                                   as uplift_pct
from like_for_like
group by department, promo_type
