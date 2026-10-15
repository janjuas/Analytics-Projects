CREATE TABLE [marts].[fct_campaign_targeting] (
    [household_sk]          VARCHAR (50)    NULL,
    [campaign_sk]           VARCHAR (50)    NULL,
    [start_date_key]        INT             NULL,
    [coupons_redeemed]      INT             NULL,
    [has_redeemed]          INT             NULL,
    [sales_during_campaign] DECIMAL (14, 2) NULL,
    [sales_before_campaign] DECIMAL (14, 2) NULL,
    [is_window_complete]    INT             NULL
);


GO