create view [staging].[stg_silver__campaigns] as select
    campaign                 as campaign_id,
    campaign_type,
    start_day                as start_day_number,
    end_day                  as end_day_number,
    end_day - start_day + 1  as duration_days
from [lh_silver].[dbo].[campaign_desc];

GO