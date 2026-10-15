select
    product_id,
    store_id,
    week_no                  as week_number,
    display_code,
    mailer_code,
    case when display_code <> '0' then 1 else 0 end as is_on_display,
    case when mailer_code <> '0' then 1 else 0 end  as is_in_mailer
from {{ source('silver', 'causal_data') }}
