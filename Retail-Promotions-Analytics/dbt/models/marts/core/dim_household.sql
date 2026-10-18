with households as (
    select
        household_key,
        min(day_number) as first_purchase_day,
        max(day_number) as last_purchase_day
    from {{ ref('stg_silver__transactions') }}
    group by household_key
),

demographics as (
    select * from {{ ref('stg_silver__households') }}
),

income_ranges as (
    select * from {{ ref('income_band_ranges') }}
)

select
    cast({{ dbt_utils.generate_surrogate_key(['h.household_key']) }} as varchar(50)) as household_sk,
    cast(h.household_key as int)                                              as household_id,
    cast(case when d.household_key is null then 0 else 1 end as int)          as has_demographics,

    cast(coalesce(d.age_band, 'Unknown') as varchar(50))                      as age_band,
    cast(coalesce(d.marital_status_code, 'Unknown') as varchar(50))           as marital_status_code,
    cast(coalesce(r.income_range, 'Unknown') as varchar(50))                  as income_band,
    cast(coalesce(d.income_band, 'Unknown') as varchar(50))                   as income_level,
    cast(coalesce(d.household_size, 'Unknown') as varchar(50))                as household_size,
    cast(coalesce(d.household_composition, 'Unknown') as varchar(50))        as household_composition,
    cast(coalesce(d.homeowner_status, 'Unknown') as varchar(50))              as homeowner_status,
    cast(coalesce(d.children_band, 'None/Unknown') as varchar(50))            as children_band,

    -- the bands are ordinal; numeric sort keys let reports order them correctly (0 = unknown)
    cast(coalesce(cast(replace(d.age_band, 'Age Group', '') as int), 0) as int)         as age_band_sort,
    cast(coalesce(r.income_band_sort, 0) as int)                                        as income_band_sort,
    cast(coalesce(cast(replace(d.household_size, '+', '') as int), 0) as int)           as household_size_sort,
    cast(coalesce(cast(replace(d.household_composition, 'Group', '') as int), 0) as int) as household_composition_sort,
    cast(case when d.children_band in ('1', '2', '3+') then cast(replace(d.children_band, '+', '') as int)
              else 0 end as int)                                                         as children_band_sort,

    cast(h.first_purchase_day as int)                                         as first_purchase_day,
    cast(h.last_purchase_day as int)                                          as last_purchase_day
from households as h
left join demographics as d
    on h.household_key = d.household_key
left join income_ranges as r
    on d.income_band = r.income_level
