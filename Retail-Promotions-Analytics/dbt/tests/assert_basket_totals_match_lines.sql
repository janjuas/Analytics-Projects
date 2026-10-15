-- Basket totals must add back to their lines.
with baskets as (
    select sum(sales_value) as sales_value, sum(line_count) as line_count from {{ ref('fct_basket') }}
),

lines as (
    select sum(sales_value) as sales_value, count(*) as line_count from {{ ref('fct_sales_line') }}
)

select b.sales_value, l.sales_value as line_sales_value, b.line_count, l.line_count as line_rows
from baskets as b
cross join lines as l
where b.sales_value <> l.sales_value or b.line_count <> l.line_count
