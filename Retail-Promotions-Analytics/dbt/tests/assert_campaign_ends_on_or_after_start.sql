-- dbt_utils.expression_is_true is not compatible with dbt-fabric's test wrapper, so this rule is a singular test.
select campaign_id, start_day_number, end_day_number
from {{ ref('dim_campaign') }}
where end_day_number < start_day_number
