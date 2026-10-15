-- Every study day from 1 to the last day must exist exactly once.
select count(*) as day_rows, max(date_key) as last_day
from {{ ref('dim_date') }}
having count(*) <> max(date_key) or min(date_key) <> 1
