{#
  QUESTION   Did campaigns increase spend? Compare targeted households with households that were
             not targeted, before vs. during each campaign (difference-in-differences).

  GRAIN      One row per campaign.

  INPUTS     ref('fct_campaign_targeting')   targeted households: sales_before_campaign, sales_during_campaign,
                                             has_redeemed, is_window_complete
             ref('dim_campaign')             campaign_id, campaign_type, start/end day, duration_days
             ref('fct_sales_line')           to compute the SAME windows for control households
             ref('dim_household')            household_sk list (all 2,500)

  OUTPUT     campaign_id, campaign_type, households_targeted, households_control,
             avg_sales_before_targeted, avg_sales_during_targeted,
             avg_sales_before_control,  avg_sales_during_control,
             did_per_household, did_pct, redemption_rate

  METHOD     did_per_household = (avg_during_T - avg_before_T) - (avg_during_C - avg_before_C)
             did_pct           = did_per_household / avg_before_T

  TRAPS
  1. Control = households NOT targeted by this campaign that shopped in the before-window
     (otherwise inactive households drag the control average to zero).
  2. Windows: before = [start - duration, start - 1], during = [start, end]. Same windows for both groups.
     fct_campaign_targeting already has them for targeted households; compute them for controls from
     fct_sales_line (date_key = study day).
  3. Exclude campaigns where is_window_complete = 0 (they run past the last transaction day).
  4. Use sales_value for both groups (fct_campaign_targeting uses sales_value).
  5. A household targeted by another overlapping campaign is still a valid control for this one,
     but note it as a limitation. Stretch goal: match controls on pre-period spend band.
  6. Joining 30 campaigns x ~2,500 households x sales lines on a date range is fine at this size;
     filter sales to the campaign's before/during span inside the join.

  WHEN DONE  Delete the config line below, then:
             python infra/sync_dbt_job.py --run --select campaign_effect
#}
{{ config(enabled=false) }}

with campaigns as (
    -- TODO: dim_campaign; compute before_start_day = start_day_number - duration_days
    select 1 as placeholder
),

targeted as (
    -- TODO: fct_campaign_targeting for complete windows (trap 3)
    select * from campaigns
),

control_candidates as (
    -- TODO: every household x campaign pair where the household is NOT in targeted for that campaign
    select * from campaigns
),

control_spend as (
    -- TODO: before / during sales for control candidates from fct_sales_line (traps 2, 4, 6);
    --       keep candidates with sales in the before-window (trap 1)
    select * from control_candidates
),

targeted_summary as (
    -- TODO: per campaign: households, avg before / during, redemption_rate = avg(has_redeemed)
    select * from targeted
),

control_summary as (
    -- TODO: per campaign: households, avg before / during
    select * from control_spend
)

-- TODO: join the two summaries to dim_campaign, compute did_per_household and did_pct
select * from targeted_summary
