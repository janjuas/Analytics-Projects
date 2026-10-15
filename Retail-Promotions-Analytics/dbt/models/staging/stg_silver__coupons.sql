select
    coupon_upc,
    product_id,
    campaign                 as campaign_id
from {{ source('silver', 'coupon') }}
