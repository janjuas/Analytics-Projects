-- No household may drop out of the household dimension (e.g. through an inner join on demographics).
select distinct t.household_key
from {{ ref('stg_silver__transactions') }} as t
left join {{ ref('dim_household') }} as h
    on t.household_key = h.household_id
where h.household_id is null
