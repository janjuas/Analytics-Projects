with source as (
    select * from {{ source('silver', 'transaction_data') }}
)

select
    {{ dbt_utils.generate_surrogate_key([
        'basket_id', 'product_id', 'household_key', 'day', 'trans_time', 'store_id',
        'quantity', 'sales_value', 'retail_disc', 'coupon_disc', 'coupon_match_disc'
    ]) }}                    as transaction_line_id,
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
from source
