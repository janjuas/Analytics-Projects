CREATE TABLE [marts].[dim_campaign] (
    [campaign_sk]               VARCHAR (50)  NULL,
    [campaign_id]               INT           NULL,
    [campaign_type]             VARCHAR (10)  NULL,
    [campaign_type_description] VARCHAR (100) NULL,
    [start_day_number]          INT           NULL,
    [end_day_number]            INT           NULL,
    [start_date]                DATE          NULL,
    [end_date]                  DATE          NULL,
    [duration_days]             INT           NULL,
    [households_targeted]       INT           NULL,
    [coupons_in_pool]           INT           NULL,
    [eligible_products]         INT           NULL
);


GO