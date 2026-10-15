-- households_targeted per campaign must match fct_campaign_targeting for complete-window campaigns.

with expected as (
    select c.campaign_id, count(*) as households_targeted
    from {{ ref('fct_campaign_targeting') }} as t
    inner join {{ ref('dim_campaign') }} as c on t.campaign_sk = c.campaign_sk
    where t.is_window_complete = 1
    group by c.campaign_id
)

select e.campaign_id, e.households_targeted, m.households_targeted as model_households_targeted
from expected as e
left join {{ ref('campaign_effect') }} as m on e.campaign_id = m.campaign_id
where m.households_targeted is null or m.households_targeted <> e.households_targeted
