select
    cast(mailer_code as varchar(1))                                    as mailer_code,
    cast(mailer_location as varchar(60))                               as mailer_location,
    cast(case when mailer_code = '0' then 0 else 1 end as int)         as is_in_mailer
from {{ ref('mailer_location_codes') }}
