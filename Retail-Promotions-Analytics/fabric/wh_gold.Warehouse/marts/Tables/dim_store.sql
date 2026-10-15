CREATE TABLE [marts].[dim_store] (
    [store_sk]           VARCHAR (50) NULL,
    [store_id]           INT          NULL,
    [has_promo_tracking] INT          NULL,
    [first_trading_day]  INT          NULL,
    [last_trading_day]   INT          NULL,
    [panel_households]   INT          NULL,
    [panel_sales_band]   VARCHAR (10) NULL
);


GO