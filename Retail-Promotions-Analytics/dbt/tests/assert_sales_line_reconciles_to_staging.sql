-- The incremental fact must hold exactly the staged lines and sales value; catches dropped or duplicated loads.
with fact as (
    select count(*) as line_count, sum(sales_value) as sales_value from {{ ref('fct_sales_line') }}
),

staged as (
    select count(*) as line_count, sum(sales_value) as sales_value from {{ ref('stg_silver__transactions') }}
)

select f.line_count, s.line_count as staged_line_count, f.sales_value, s.sales_value as staged_sales_value
from fact as f
cross join staged as s
where f.line_count <> s.line_count or f.sales_value <> s.sales_value
