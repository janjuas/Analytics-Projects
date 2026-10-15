{#
  QUESTION   Is private label gaining share, and in which departments?

  GRAIN      One row per department.

  INPUTS     ref('fct_sales_line')   sales_value, date_key
             ref('dim_product')      department, brand_type ('National' | 'Private')
             ref('dim_date')         study_year (1 = days 1-365, 2 = days 366+)

  OUTPUT     department, sales_value_y1, sales_value_y2, private_share_y1, private_share_y2,
             share_change_pp

  DEFINITIONS
             private_share_yN = private sales / total sales in year N
             share_change_pp  = (private_share_y2 - private_share_y1) * 100   (percentage points)

  TRAPS
  1. Year 2 is shorter (346 transaction days vs 365). Shares are unaffected, but don't compare raw
     sales totals across years without saying so.
  2. Departments with tiny sales give extreme shares. Keep departments with >= 1,000 sales value in
     each year.
  3. Conditional aggregation (sum(case when ... then sales_value else 0 end)) gives all four
     numbers in one pass; no pivot needed.
  4. Guard divisions with nullif(total, 0).

  WHEN DONE  Delete the config line below, then:
             python infra/sync_dbt_job.py --run --select private_label_share
#}
{{ config(enabled=false) }}

with sales as (
    -- TODO: fct_sales_line joined to dim_product (department, brand_type) and dim_date (study_year)
    select 1 as placeholder
),

department_year as (
    -- TODO: conditional aggregation per department (trap 3)
    select * from sales
)

-- TODO: shares, share_change_pp, and the volume filter (traps 2, 4)
select * from department_year
