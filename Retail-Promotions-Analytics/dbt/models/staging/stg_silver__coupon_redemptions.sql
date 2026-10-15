select
    household_key,
    day                      as day_number,
    coupon_upc,
    campaign                 as campaign_id
from {{ source('silver', 'coupon_redempt') }}
