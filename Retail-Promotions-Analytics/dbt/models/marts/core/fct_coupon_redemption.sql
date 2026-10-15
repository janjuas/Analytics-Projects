with redemptions as (
    select household_key, day_number, coupon_upc, campaign_id
    from {{ ref('stg_silver__coupon_redemptions') }}
),

-- coupon discount on that household's same-day purchases of products the coupon is valid for
matched_value as (
    select
        r.household_key,
        r.day_number,
        r.coupon_upc,
        r.campaign_id,
        sum(-t.coupon_discount) as coupon_discount_value,
        count(*)                as matched_lines
    from redemptions as r
    inner join {{ ref('stg_silver__coupons') }} as cp
        on r.coupon_upc = cp.coupon_upc
        and r.campaign_id = cp.campaign_id
    inner join {{ ref('stg_silver__transactions') }} as t
        on t.household_key = r.household_key
        and t.day_number = r.day_number
        and t.product_id = cp.product_id
        and t.coupon_discount < 0
    group by r.household_key, r.day_number, r.coupon_upc, r.campaign_id
)

select
    cast({{ dbt_utils.generate_surrogate_key(['r.household_key', 'r.day_number', 'r.coupon_upc', 'r.campaign_id']) }} as varchar(50))
                                                                                    as redemption_id,
    cast({{ dbt_utils.generate_surrogate_key(['r.household_key']) }} as varchar(50)) as household_sk,
    cast({{ dbt_utils.generate_surrogate_key(['r.campaign_id']) }} as varchar(50))   as campaign_sk,
    cast(r.day_number as int)                                                       as date_key,
    cast(r.coupon_upc as varchar(20))                                               as coupon_upc,
    cast(coalesce(m.coupon_discount_value, 0) as decimal(12, 2))                    as coupon_discount_value,
    cast(coalesce(m.matched_lines, 0) as int)                                       as matched_lines
from redemptions as r
left join matched_value as m
    on r.household_key = m.household_key
    and r.day_number = m.day_number
    and r.coupon_upc = m.coupon_upc
    and r.campaign_id = m.campaign_id
