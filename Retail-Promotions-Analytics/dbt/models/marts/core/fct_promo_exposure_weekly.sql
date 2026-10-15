with tracked_stores as (
    select store_id from {{ ref('dim_store') }} where has_promo_tracking = 1
),

tracked_weeks as (
    select week_number from {{ ref('dim_week') }} where is_promo_tracked_week = 1
),

-- causal_data only lists promoted product-store-weeks, so non-promoted weeks come from sales
weekly_sales as (
    select
        t.product_id,
        t.store_id,
        t.week_number,
        sum(t.quantity)                                                   as units_sold,
        sum(t.sales_value)                                                as sales_value,
        sum(t.sales_value - t.retail_discount - t.coupon_match_discount)  as shelf_value,
        count(distinct t.basket_id)                                       as baskets
    from {{ ref('stg_silver__transactions') }} as t
    inner join tracked_stores as s on t.store_id = s.store_id
    inner join tracked_weeks as w on t.week_number = w.week_number
    group by t.product_id, t.store_id, t.week_number
),

exposure as (
    select product_id, store_id, week_number, display_code, mailer_code
    from {{ ref('stg_silver__causal') }}
),

combined as (
    select
        coalesce(e.product_id, s.product_id)   as product_id,
        coalesce(e.store_id, s.store_id)       as store_id,
        coalesce(e.week_number, s.week_number) as week_number,
        coalesce(e.display_code, '0')          as display_code,
        coalesce(e.mailer_code, '0')           as mailer_code,
        coalesce(s.units_sold, 0)              as units_sold,
        coalesce(s.sales_value, 0)             as sales_value,
        coalesce(s.shelf_value, 0)             as shelf_value,
        coalesce(s.baskets, 0)                 as baskets
    from exposure as e
    full outer join weekly_sales as s
        on e.product_id = s.product_id
        and e.store_id = s.store_id
        and e.week_number = s.week_number
)

select
    cast({{ dbt_utils.generate_surrogate_key(['product_id']) }} as varchar(50))   as product_sk,
    cast({{ dbt_utils.generate_surrogate_key(['store_id']) }} as varchar(50))     as store_sk,
    cast(week_number as int)                                                    as week_number,
    cast(display_code as varchar(1))                                            as display_code,
    cast(mailer_code as varchar(1))                                             as mailer_code,
    cast(case when display_code <> '0' then 1 else 0 end as int)                as is_on_display,
    cast(case when mailer_code <> '0' then 1 else 0 end as int)                 as is_in_mailer,
    cast(case when display_code <> '0' or mailer_code <> '0' then 1 else 0 end as int) as is_promoted,
    cast(units_sold as int)                                                     as units_sold,
    cast(sales_value as decimal(14, 2))                                         as sales_value,
    cast(shelf_value as decimal(14, 2))                                         as shelf_value,
    cast(baskets as int)                                                        as baskets
from combined
