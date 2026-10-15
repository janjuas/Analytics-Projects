-- Within each commodity, band shares of units must add up to 1.
-- Enable together with discount_depth_response by deleting the config line.
{{ config(enabled=false) }}

select commodity, sum(units_share_of_commodity) as total_share
from {{ ref('discount_depth_response') }}
group by commodity
having abs(sum(units_share_of_commodity) - 1) > 0.001
