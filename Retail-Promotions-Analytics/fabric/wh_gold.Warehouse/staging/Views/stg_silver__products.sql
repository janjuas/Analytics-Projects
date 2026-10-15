create view [staging].[stg_silver__products] as select
    product_id,
    manufacturer             as manufacturer_id,
    department,
    brand                    as brand_type,
    commodity_desc           as commodity,
    sub_commodity_desc       as sub_commodity,
    curr_size_of_product     as product_size
from [lh_silver].[dbo].[product];

GO