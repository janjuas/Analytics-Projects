CREATE TABLE [marts].[fct_sales_line] (
    [transaction_line_id]         VARCHAR (50)    NULL,
    [basket_id]                   BIGINT          NULL,
    [date_key]                    INT             NULL,
    [week_number]                 INT             NULL,
    [household_sk]                VARCHAR (50)    NULL,
    [product_sk]                  VARCHAR (50)    NULL,
    [store_sk]                    VARCHAR (50)    NULL,
    [transaction_time_hhmm]       INT             NULL,
    [quantity]                    INT             NULL,
    [shelf_value]                 DECIMAL (12, 2) NULL,
    [sales_value]                 DECIMAL (12, 2) NULL,
    [customer_paid_value]         DECIMAL (12, 2) NULL,
    [loyalty_discount_value]      DECIMAL (12, 2) NULL,
    [coupon_discount_value]       DECIMAL (12, 2) NULL,
    [coupon_match_discount_value] DECIMAL (12, 2) NULL,
    [shelf_unit_price]            DECIMAL (12, 4) NULL,
    [paid_unit_price]             DECIMAL (12, 4) NULL,
    [has_loyalty_discount]        INT             NULL,
    [has_coupon]                  INT             NULL
);


GO