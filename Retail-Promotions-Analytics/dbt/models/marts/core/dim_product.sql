select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_sk,
    product_id,
    manufacturer_id,
    coalesce(department, 'Unknown')       as department,
    coalesce(commodity, 'Unknown')        as commodity,
    coalesce(sub_commodity, 'Unknown')    as sub_commodity,
    brand_type,
    case when brand_type = 'Private' then 1 else 0 end as is_private_label,
    product_size
from {{ ref('stg_silver__products') }}
