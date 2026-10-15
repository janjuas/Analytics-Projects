with tracking_window as (
    select min(week_number) as first_week, max(week_number) as last_week
    from {{ ref('stg_silver__causal') }}
)

select
    cast(d.week_number as int)                                                    as week_number,
    cast(min(d.calendar_date) as date)                                            as week_start_date,
    cast(max(d.calendar_date) as date)                                            as week_end_date,
    cast(count(*) as int)                                                         as days_in_week,
    cast(min(d.study_year) as int)                                                as study_year,
    cast(case when d.week_number between w.first_week and w.last_week then 1 else 0 end as int)
                                                                                  as is_promo_tracked_week
from {{ ref('dim_date') }} as d
cross join tracking_window as w
group by d.week_number, w.first_week, w.last_week
