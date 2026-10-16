CREATE TABLE [analysis].[household_segment_summary] (
    [income_band]                VARCHAR (50)    NULL,
    [income_band_sort]           INT             NULL,
    [household_composition]      VARCHAR (50)    NULL,
    [household_composition_sort] INT             NULL,
    [households]                 INT             NULL,
    [baskets]                    INT             NULL,
    [baskets_per_household]      DECIMAL (12, 2) NULL,
    [avg_basket_value]           DECIMAL (12, 2) NULL,
    [sales_per_household]        DECIMAL (14, 2) NULL,
    [loyalty_discount_share]     DECIMAL (9, 4)  NULL,
    [coupon_basket_share]        DECIMAL (9, 4)  NULL,
    [is_small_segment]           INT             NULL
);


GO