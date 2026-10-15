-- Within each department-commodity, band shares of units must add up to 1 (within rounding).
select department, commodity, sum(units_share_of_commodity) as total_share
from {{ ref('discount_depth_response') }}
group by department, commodity
having abs(sum(units_share_of_commodity) - 1) > 0.001
