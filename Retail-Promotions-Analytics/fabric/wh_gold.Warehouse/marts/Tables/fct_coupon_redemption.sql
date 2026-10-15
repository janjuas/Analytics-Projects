CREATE TABLE [marts].[fct_coupon_redemption] (
    [redemption_id]         VARCHAR (50)    NULL,
    [household_sk]          VARCHAR (50)    NULL,
    [campaign_sk]           VARCHAR (50)    NULL,
    [date_key]              INT             NULL,
    [coupon_upc]            VARCHAR (20)    NULL,
    [coupon_discount_value] DECIMAL (12, 2) NULL,
    [matched_lines]         INT             NULL
);


GO