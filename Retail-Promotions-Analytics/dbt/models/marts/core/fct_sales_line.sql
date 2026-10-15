{{
    config(
        materialized='incremental',
        unique_key='transaction_line_id',
        incremental_strategy='delete+insert',
        on_schema_change='fail'
    )
}}

with lines as (
    select * from {{ ref('stg_silver__transactions') }}
    {% if is_incremental() %}
    where day_number > (select max(date_key) from {{ this }})
    {% endif %}
),

priced as (
    select
        *,
        -- shelf value follows the user guide's worked examples: amount received plus the loyalty discount
        -- and the retailer's coupon match (both stored as negatives)
        sales_value - retail_discount - coupon_match_discount as shelf_value,
        -- the customer pays less than sales_value when a manufacturer coupon is used
        sales_value + coupon_discount                         as customer_paid_value
    from lines
)

select
    cast(transaction_line_id as varchar(50))                                         as transaction_line_id,
    cast(basket_id as bigint)                                                        as basket_id,
    cast(day_number as int)                                                          as date_key,
    cast(week_number as int)                                                         as week_number,
    cast({{ dbt_utils.generate_surrogate_key(['household_key']) }} as varchar(50))   as household_sk,
    cast({{ dbt_utils.generate_surrogate_key(['product_id']) }} as varchar(50))      as product_sk,
    cast({{ dbt_utils.generate_surrogate_key(['store_id']) }} as varchar(50))        as store_sk,
    cast(transaction_time_hhmm as int)                                               as transaction_time_hhmm,
    cast(quantity as int)                                                            as quantity,
    cast(shelf_value as decimal(12, 2))                                              as shelf_value,
    cast(sales_value as decimal(12, 2))                                              as sales_value,
    cast(customer_paid_value as decimal(12, 2))                                      as customer_paid_value,
    cast(-retail_discount as decimal(12, 2))                                         as loyalty_discount_value,
    cast(-coupon_discount as decimal(12, 2))                                         as coupon_discount_value,
    cast(-coupon_match_discount as decimal(12, 2))                                   as coupon_match_discount_value,
    cast(case when quantity > 0 then shelf_value / quantity end as decimal(12, 4))   as shelf_unit_price,
    cast(case when quantity > 0 then customer_paid_value / quantity end as decimal(12, 4)) as paid_unit_price,
    cast(case when retail_discount < 0 then 1 else 0 end as int)                     as has_loyalty_discount,
    cast(case when coupon_discount < 0 then 1 else 0 end as int)                     as has_coupon
from priced
