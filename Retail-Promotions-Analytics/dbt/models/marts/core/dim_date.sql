with digits as (
    select v from (values (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) as d (v)
),

day_numbers as (
    select hundreds.v * 100 + tens.v * 10 + units.v + 1 as day_number
    from digits as hundreds
    cross join digits as tens
    cross join digits as units
),

-- campaigns run past the last transaction day, so the calendar covers every source
bounds as (
    select
        (select max(day_number) from {{ ref('stg_silver__transactions') }}) as last_transaction_day,
        (
            select max(last_day)
            from (
                select max(day_number) as last_day from {{ ref('stg_silver__transactions') }}
                union all
                select max(end_day_number) from {{ ref('stg_silver__campaigns') }}
                union all
                select max(day_number) from {{ ref('stg_silver__coupon_redemptions') }}
            ) as source_days
        ) as last_day
),

calendar as (
    select
        d.day_number,
        b.last_transaction_day,
        dateadd(day, d.day_number - 1, cast('{{ var("day_one_date") }}' as date)) as calendar_date
    from day_numbers as d
    cross join bounds as b
    where d.day_number <= b.last_day
),

enriched as (
    select
        *,
        -- 1900-01-01 was a Monday, so this is independent of the server's DATEFIRST setting
        datediff(day, cast('1900-01-01' as date), calendar_date) % 7 + 1 as day_of_week_number
    from calendar
)

select
    cast(day_number as int)                                                  as date_key,
    cast(day_number as int)                                                  as day_number,
    cast(calendar_date as date)                                              as calendar_date,
    cast((day_number + 1) / 7 + 1 as int)                                    as week_number,
    cast(dateadd(day, 1 - day_of_week_number, calendar_date) as date)        as week_start_date,
    cast(day_of_week_number as int)                                          as day_of_week_number,
    cast(datename(weekday, calendar_date) as varchar(10))                    as day_of_week_name,
    cast(case when day_of_week_number >= 6 then 1 else 0 end as int)         as is_weekend,
    cast(month(calendar_date) as int)                                        as month_number,
    cast(datename(month, calendar_date) as varchar(10))                      as month_name,
    cast(datepart(quarter, calendar_date) as int)                            as quarter_number,
    cast(year(calendar_date) as int)                                         as calendar_year,
    cast(case when day_number <= 365 then 1 else 2 end as int)               as study_year,
    cast(case when day_number <= last_transaction_day then 1 else 0 end as int) as is_in_transaction_window
from enriched
