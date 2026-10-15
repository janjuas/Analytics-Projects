select
    household_key,
    age_desc                 as age_band,
    marital_status_code,
    income_desc              as income_band,
    household_size_desc      as household_size,
    hh_comp_desc             as household_composition,
    homeowner_desc           as homeowner_status,
    kid_category_desc        as children_band
from {{ source('silver', 'hh_demographic') }}
