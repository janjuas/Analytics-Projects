with lines as (
    select * from {{ ref('fct_sales_line') }}
),

baskets as (
    select
        basket_id,
        household_sk,
        store_sk,
        date_key,
        week_number,
        min(transaction_time_hhmm)        as basket_time_hhmm,
        count(*)                          as line_count,
        sum(quantity)                     as item_quantity,
        count(distinct product_sk)        as distinct_products,
        sum(shelf_value)                  as shelf_value,
        sum(sales_value)                  as sales_value,
        sum(customer_paid_value)          as customer_paid_value,
        sum(loyalty_discount_value)       as loyalty_discount_value,
        sum(coupon_discount_value)        as coupon_discount_value,
        max(has_coupon)                   as has_coupon
    from lines
    group by basket_id, household_sk, store_sk, date_key, week_number
)

select
    cast(basket_id as bigint)                         as basket_id,
    cast(household_sk as varchar(50))                 as household_sk,
    cast(store_sk as varchar(50))                     as store_sk,
    cast(date_key as int)                             as date_key,
    cast(week_number as int)                          as week_number,
    cast(basket_time_hhmm as int)                     as basket_time_hhmm,
    cast(line_count as int)                           as line_count,
    cast(item_quantity as int)                        as item_quantity,
    cast(distinct_products as int)                    as distinct_products,
    cast(shelf_value as decimal(14, 2))               as shelf_value,
    cast(sales_value as decimal(14, 2))               as sales_value,
    cast(customer_paid_value as decimal(14, 2))       as customer_paid_value,
    cast(loyalty_discount_value as decimal(14, 2))    as loyalty_discount_value,
    cast(coupon_discount_value as decimal(14, 2))     as coupon_discount_value,
    cast(case when shelf_value > 0 then loyalty_discount_value / shelf_value end as decimal(9, 4))
                                                      as loyalty_discount_share,
    cast(has_coupon as int)                           as has_coupon
from baskets
