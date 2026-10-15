create view [staging].[stg_silver__campaign_households] as select
    household_key,
    campaign                 as campaign_id,
    campaign_type
from [lh_silver].[dbo].[campaign_table];

GO