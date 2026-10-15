select
    campaign                 as campaign_id,
    campaign_type,
    start_day                as start_day_number,
    end_day                  as end_day_number,
    end_day - start_day + 1  as duration_days
from {{ source('silver', 'campaign_desc') }}
