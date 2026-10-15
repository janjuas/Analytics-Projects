{#
  Is private label gaining share, and in which departments?
  Grain: one row per department (merchandise only), study year 1 vs. year 2.
  Year 2 has 346 transaction days vs. 365, so compare shares rather than raw totals.
#}

with sales as (
    select
        p.department,
        p.brand_type,
        d.study_year,
        f.sales_value
    from {{ ref('fct_sales_line') }} as f
    inner join {{ ref('dim_product') }} as p
        on f.product_sk = p.product_sk
    inner join {{ ref('dim_date') }} as d
        on f.date_key = d.date_key
    where p.is_merchandise = 1
),

department_year as (
    select
        department,
        sum(case when study_year = 1 then sales_value else 0 end)                              as sales_value_y1,
        sum(case when study_year = 2 then sales_value else 0 end)                              as sales_value_y2,
        sum(case when study_year = 1 and brand_type = 'Private' then sales_value else 0 end)   as private_sales_y1,
        sum(case when study_year = 2 and brand_type = 'Private' then sales_value else 0 end)   as private_sales_y2
    from sales
    group by department
),

shares as (
    select
        department,
        sales_value_y1,
        sales_value_y2,
        private_sales_y1 / nullif(sales_value_y1, 0) as private_share_y1,
        private_sales_y2 / nullif(sales_value_y2, 0) as private_share_y2
    from department_year
    -- departments with tiny sales give extreme shares
    where sales_value_y1 >= 1000
      and sales_value_y2 >= 1000
)

select
    cast(department as varchar(100))                                          as department,
    cast(sales_value_y1 as decimal(14, 2))                                    as sales_value_y1,
    cast(sales_value_y2 as decimal(14, 2))                                    as sales_value_y2,
    cast(private_share_y1 as decimal(9, 4))                                   as private_share_y1,
    cast(private_share_y2 as decimal(9, 4))                                   as private_share_y2,
    cast((private_share_y2 - private_share_y1) * 100 as decimal(9, 2))        as share_change_pp
from shares
