CREATE TABLE [marts].[fct_promo_exposure_weekly] (
    [product_sk]    VARCHAR (50)    NULL,
    [store_sk]      VARCHAR (50)    NULL,
    [week_number]   INT             NULL,
    [display_code]  VARCHAR (1)     NULL,
    [mailer_code]   VARCHAR (1)     NULL,
    [is_on_display] INT             NULL,
    [is_in_mailer]  INT             NULL,
    [is_promoted]   INT             NULL,
    [units_sold]    INT             NULL,
    [sales_value]   DECIMAL (14, 2) NULL,
    [shelf_value]   DECIMAL (14, 2) NULL,
    [baskets]       INT             NULL
);


GO