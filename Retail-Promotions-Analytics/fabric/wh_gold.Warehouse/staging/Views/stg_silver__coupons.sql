create view [staging].[stg_silver__coupons] as select
    coupon_upc,
    product_id,
    campaign                 as campaign_id
from [lh_silver].[dbo].[coupon];

GO