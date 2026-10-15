CREATE TABLE [marts].[fct_basket] (
    [basket_id]              BIGINT          NULL,
    [household_sk]           VARCHAR (50)    NULL,
    [store_sk]               VARCHAR (50)    NULL,
    [date_key]               INT             NULL,
    [week_number]            INT             NULL,
    [basket_time_hhmm]       INT             NULL,
    [line_count]             INT             NULL,
    [item_quantity]          INT             NULL,
    [distinct_products]      INT             NULL,
    [shelf_value]            DECIMAL (14, 2) NULL,
    [sales_value]            DECIMAL (14, 2) NULL,
    [customer_paid_value]    DECIMAL (14, 2) NULL,
    [loyalty_discount_value] DECIMAL (14, 2) NULL,
    [coupon_discount_value]  DECIMAL (14, 2) NULL,
    [loyalty_discount_share] DECIMAL (9, 4)  NULL,
    [has_coupon]             INT             NULL
);


GO