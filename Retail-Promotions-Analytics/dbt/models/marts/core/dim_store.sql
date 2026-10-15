with store_activity as (
    select
        store_id,
        min(day_number)               as first_trading_day,
        max(day_number)               as last_trading_day,
        count(distinct household_key) as panel_households,
        sum(sales_value)              as panel_sales_value
    from {{ ref('stg_silver__transactions') }}
    group by store_id
),

promo_tracked as (
    select distinct store_id from {{ ref('stg_silver__causal') }}
)

select
    cast({{ dbt_utils.generate_surrogate_key(['a.store_id']) }} as varchar(50)) as store_sk,
    cast(a.store_id as int)                                                   as store_id,
    cast(case when p.store_id is null then 0 else 1 end as int)               as has_promo_tracking,
    cast(a.first_trading_day as int)                                          as first_trading_day,
    cast(a.last_trading_day as int)                                           as last_trading_day,
    cast(a.panel_households as int)                                           as panel_households,
    cast(
        case ntile(3) over (order by a.panel_sales_value desc)
            when 1 then 'High'
            when 2 then 'Medium'
            else 'Low'
        end as varchar(10)
    )                                                                         as panel_sales_band
from store_activity as a
left join promo_tracked as p
    on a.store_id = p.store_id
