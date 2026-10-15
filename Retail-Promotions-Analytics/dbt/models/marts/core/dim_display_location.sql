select
    cast(display_code as varchar(1))                                   as display_code,
    cast(display_location as varchar(60))                              as display_location,
    cast(case when display_code = '0' then 0 else 1 end as int)        as is_on_display
from {{ ref('display_location_codes') }}
