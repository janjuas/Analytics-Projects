select
    household_key,
    campaign                 as campaign_id,
    campaign_type
from {{ source('silver', 'campaign_table') }}
