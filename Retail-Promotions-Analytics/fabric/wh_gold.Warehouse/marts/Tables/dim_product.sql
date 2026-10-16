CREATE TABLE [marts].[dim_product] (
    [product_sk]       VARCHAR (50)   NULL,
    [product_id]       INT            NULL,
    [manufacturer_id]  INT            NULL,
    [department]       VARCHAR (8000) NULL,
    [commodity]        VARCHAR (8000) NULL,
    [sub_commodity]    VARCHAR (8000) NULL,
    [brand_type]       VARCHAR (8000) NULL,
    [is_private_label] INT            NULL,
    [is_merchandise]   INT            NULL,
    [product_size]     VARCHAR (8000) NULL
);


GO