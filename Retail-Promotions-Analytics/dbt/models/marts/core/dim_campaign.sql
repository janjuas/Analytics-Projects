with campaigns as (
    select * from {{ ref('stg_silver__campaigns') }}
),

targeting as (
    select campaign_id, count(distinct household_key) as households_targeted
    from {{ ref('stg_silver__campaign_households') }}
    group by campaign_id
),

coupon_pool as (
    select
        campaign_id,
        count(distinct coupon_upc) as coupons_in_pool,
        count(distinct product_id) as eligible_products
    from {{ ref('stg_silver__coupons') }}
    group by campaign_id
),

dates as (
    select date_key, calendar_date from {{ ref('dim_date') }}
)

select
    cast({{ dbt_utils.generate_surrogate_key(['c.campaign_id']) }} as varchar(50)) as campaign_sk,
    cast(c.campaign_id as int)                                                as campaign_id,
    cast(c.campaign_type as varchar(10))                                      as campaign_type,
    cast(
        case c.campaign_type
            when 'TypeA' then 'Targeted: each household receives 16 coupons chosen from the pool by purchase history'
            else 'Mass: every participating household receives every coupon in the campaign'
        end as varchar(100)
    )                                                                         as campaign_type_description,
    cast(c.start_day_number as int)                                           as start_day_number,
    cast(c.end_day_number as int)                                             as end_day_number,
    cast(sd.calendar_date as date)                                            as start_date,
    cast(ed.calendar_date as date)                                            as end_date,
    cast(c.duration_days as int)                                              as duration_days,
    cast(coalesce(t.households_targeted, 0) as int)                           as households_targeted,
    cast(coalesce(p.coupons_in_pool, 0) as int)                               as coupons_in_pool,
    cast(coalesce(p.eligible_products, 0) as int)                             as eligible_products
from campaigns as c
left join targeting as t on c.campaign_id = t.campaign_id
left join coupon_pool as p on c.campaign_id = p.campaign_id
left join dates as sd on c.start_day_number = sd.date_key
left join dates as ed on c.end_day_number = ed.date_key
