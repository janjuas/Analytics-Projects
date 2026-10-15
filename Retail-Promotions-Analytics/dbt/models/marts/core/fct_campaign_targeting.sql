with targeting as (
    select household_key, campaign_id from {{ ref('stg_silver__campaign_households') }}
),

campaigns as (
    select campaign_id, start_day_number, end_day_number, duration_days
    from {{ ref('stg_silver__campaigns') }}
),

last_transaction_day as (
    select max(day_number) as day_number from {{ ref('stg_silver__transactions') }}
),

redemptions as (
    select household_key, campaign_id, count(*) as coupons_redeemed
    from {{ ref('stg_silver__coupon_redemptions') }}
    group by household_key, campaign_id
),

-- spend while the campaign ran vs. an equal-length window immediately before it
spend as (
    select
        tg.household_key,
        tg.campaign_id,
        sum(case when t.day_number between c.start_day_number and c.end_day_number
                 then t.sales_value else 0 end)                                           as sales_during_campaign,
        sum(case when t.day_number < c.start_day_number then t.sales_value else 0 end)   as sales_before_campaign
    from targeting as tg
    inner join campaigns as c on tg.campaign_id = c.campaign_id
    inner join {{ ref('stg_silver__transactions') }} as t
        on t.household_key = tg.household_key
        and t.day_number between c.start_day_number - c.duration_days and c.end_day_number
    group by tg.household_key, tg.campaign_id
)

select
    cast({{ dbt_utils.generate_surrogate_key(['tg.household_key']) }} as varchar(50)) as household_sk,
    cast({{ dbt_utils.generate_surrogate_key(['tg.campaign_id']) }} as varchar(50))   as campaign_sk,
    cast(c.start_day_number as int)                                                  as start_date_key,
    cast(coalesce(r.coupons_redeemed, 0) as int)                                     as coupons_redeemed,
    cast(case when r.coupons_redeemed > 0 then 1 else 0 end as int)                  as has_redeemed,
    cast(coalesce(s.sales_during_campaign, 0) as decimal(14, 2))                     as sales_during_campaign,
    cast(coalesce(s.sales_before_campaign, 0) as decimal(14, 2))                     as sales_before_campaign,
    -- campaigns ending after the last transaction day have a truncated "during" window
    cast(case when c.end_day_number <= l.day_number then 1 else 0 end as int)        as is_window_complete
from targeting as tg
inner join campaigns as c on tg.campaign_id = c.campaign_id
cross join last_transaction_day as l
left join redemptions as r
    on tg.household_key = r.household_key
    and tg.campaign_id = r.campaign_id
left join spend as s
    on tg.household_key = s.household_key
    and tg.campaign_id = s.campaign_id
