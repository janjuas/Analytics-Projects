create view [staging].[stg_silver__transactions] as with source as (
    select * from [lh_silver].[dbo].[transaction_data]
)

select
    
    lower(convert(varchar(50), hashbytes('md5', coalesce(convert(varchar(8000), concat(coalesce(cast(basket_id as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(product_id as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(household_key as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(day as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(trans_time as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(store_id as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(quantity as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(sales_value as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(retail_disc as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(coupon_disc as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'), '-', coalesce(cast(coupon_match_disc as VARCHAR(8000)), '_dbt_utils_surrogate_key_null_'))), '')), 2))
                    as transaction_line_id,
    basket_id,
    household_key,
    product_id,
    store_id,
    day                      as day_number,
    week_no                  as week_number,
    trans_time               as transaction_time_hhmm,
    quantity,
    sales_value,
    retail_disc              as retail_discount,
    coupon_disc              as coupon_discount,
    coupon_match_disc        as coupon_match_discount
from source;

GO