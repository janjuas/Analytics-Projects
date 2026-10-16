CREATE TABLE [analysis].[campaign_effect] (
    [campaign_id]                 INT             NULL,
    [campaign_type]               VARCHAR (10)    NULL,
    [households_targeted]         INT             NULL,
    [households_targeted_active]  INT             NULL,
    [households_control]          INT             NULL,
    [avg_sales_before_targeted]   DECIMAL (12, 2) NULL,
    [avg_sales_during_targeted]   DECIMAL (12, 2) NULL,
    [avg_sales_before_control]    DECIMAL (12, 2) NULL,
    [avg_sales_during_control]    DECIMAL (12, 2) NULL,
    [did_per_household]           DECIMAL (12, 2) NULL,
    [did_pct]                     DECIMAL (9, 4)  NULL,
    [did_per_household_unmatched] DECIMAL (12, 2) NULL,
    [redemption_rate]             DECIMAL (9, 4)  NULL,
    [is_small_campaign]           INT             NULL
);


GO