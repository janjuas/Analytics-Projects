{#
  Did campaigns increase spend? Difference-in-differences per campaign: change in average sales per
  household from the before-window to the campaign window, targeted minus non-targeted households.
  Grain: one row per campaign with a complete window (campaigns running past the last transaction day
  are excluded).

  Windows: before = [start - duration, start - 1], during = [start, end], identical for both groups.
  Both groups are limited to households that shopped in the before-window.

  Targeted households spend roughly twice as much as the rest before a campaign starts, so the main
  estimate (did_per_household) is matched: households are split into before-window spend quintiles
  within each campaign, the difference-in-differences is computed within each quintile, and quintiles
  are weighted by their number of targeted households. did_per_household_unmatched is the simple
  all-households comparison, kept to show the effect of matching.
  A control household may have been targeted by another, overlapping campaign.
#}

with campaigns as (
    select
        campaign_sk,
        campaign_id,
        campaign_type,
        start_day_number,
        end_day_number,
        start_day_number - duration_days as before_start_day
    from {{ ref('dim_campaign') }}
),

targeted as (
    select
        campaign_sk,
        household_sk,
        sales_before_campaign as sales_before,
        sales_during_campaign as sales_during,
        has_redeemed
    from {{ ref('fct_campaign_targeting') }}
    where is_window_complete = 1
),

complete_campaigns as (
    select c.*
    from campaigns as c
    where exists (select 1 from targeted as t where t.campaign_sk = c.campaign_sk)
),

control_candidates as (
    select c.campaign_sk, h.household_sk
    from complete_campaigns as c
    cross join {{ ref('dim_household') }} as h
    where not exists (
        select 1
        from {{ ref('fct_campaign_targeting') }} as t
        where t.campaign_sk = c.campaign_sk
          and t.household_sk = h.household_sk
    )
),

control_spend as (
    select
        cc.campaign_sk,
        cc.household_sk,
        sum(case when s.date_key < c.start_day_number then s.sales_value else 0 end)  as sales_before,
        sum(case when s.date_key >= c.start_day_number then s.sales_value else 0 end) as sales_during
    from control_candidates as cc
    inner join complete_campaigns as c
        on cc.campaign_sk = c.campaign_sk
    inner join {{ ref('fct_sales_line') }} as s
        on s.household_sk = cc.household_sk
        and s.date_key between c.before_start_day and c.end_day_number
    group by cc.campaign_sk, cc.household_sk
),

-- households active in the before-window, both groups
active as (
    select campaign_sk, 'T' as grp, sales_before, sales_during
    from targeted
    where sales_before > 0
    union all
    select campaign_sk, 'C' as grp, sales_before, sales_during
    from control_spend
    where sales_before > 0
),

banded as (
    select
        *,
        ntile(5) over (partition by campaign_sk order by sales_before) as spend_quintile
    from active
),

quintile_group as (
    select
        campaign_sk,
        spend_quintile,
        grp,
        count(*)                                      as households,
        avg(cast(sales_before as decimal(18, 4)))     as avg_before,
        avg(cast(sales_during as decimal(18, 4)))     as avg_during
    from banded
    group by campaign_sk, spend_quintile, grp
),

matched as (
    select
        t.campaign_sk,
        sum(((t.avg_during - t.avg_before) - (c.avg_during - c.avg_before)) * t.households)
            / sum(t.households)                       as did_matched
    from quintile_group as t
    inner join quintile_group as c
        on t.campaign_sk = c.campaign_sk
        and t.spend_quintile = c.spend_quintile
        and c.grp = 'C'
    where t.grp = 'T'
    group by t.campaign_sk
),

group_summary as (
    select
        campaign_sk,
        grp,
        count(*)                                      as households,
        avg(cast(sales_before as decimal(18, 4)))     as avg_before,
        avg(cast(sales_during as decimal(18, 4)))     as avg_during
    from active
    group by campaign_sk, grp
),

targeted_counts as (
    select
        campaign_sk,
        count(*)                                      as households_targeted,
        avg(cast(has_redeemed as decimal(18, 4)))     as redemption_rate
    from targeted
    group by campaign_sk
),

effect as (
    select
        c.campaign_id,
        c.campaign_type,
        tc.households_targeted,
        t.households as households_targeted_active,
        k.households as households_control,
        t.avg_before as avg_sales_before_targeted,
        t.avg_during as avg_sales_during_targeted,
        k.avg_before as avg_sales_before_control,
        k.avg_during as avg_sales_during_control,
        m.did_matched as did_per_household,
        (t.avg_during - t.avg_before) - (k.avg_during - k.avg_before) as did_per_household_unmatched,
        tc.redemption_rate
    from complete_campaigns as c
    inner join targeted_counts as tc on c.campaign_sk = tc.campaign_sk
    inner join group_summary as t on c.campaign_sk = t.campaign_sk and t.grp = 'T'
    inner join group_summary as k on c.campaign_sk = k.campaign_sk and k.grp = 'C'
    inner join matched as m on c.campaign_sk = m.campaign_sk
)

select
    cast(campaign_id as int)                                                         as campaign_id,
    cast(campaign_type as varchar(10))                                               as campaign_type,
    cast(households_targeted as int)                                                 as households_targeted,
    cast(households_targeted_active as int)                                          as households_targeted_active,
    cast(households_control as int)                                                  as households_control,
    cast(avg_sales_before_targeted as decimal(12, 2))                                as avg_sales_before_targeted,
    cast(avg_sales_during_targeted as decimal(12, 2))                                as avg_sales_during_targeted,
    cast(avg_sales_before_control as decimal(12, 2))                                 as avg_sales_before_control,
    cast(avg_sales_during_control as decimal(12, 2))                                 as avg_sales_during_control,
    cast(did_per_household as decimal(12, 2))                                        as did_per_household,
    cast(did_per_household / nullif(avg_sales_before_targeted, 0) as decimal(9, 4))  as did_pct,
    cast(did_per_household_unmatched as decimal(12, 2))                              as did_per_household_unmatched,
    cast(redemption_rate as decimal(9, 4))                                           as redemption_rate,
    cast(case when households_targeted_active < 30 then 1 else 0 end as int)         as is_small_campaign
from effect
