create view [staging].[stg_silver__coupon_redemptions] as select
    household_key,
    day                      as day_number,
    coupon_upc,
    campaign                 as campaign_id
from [lh_silver].[dbo].[coupon_redempt];

GO