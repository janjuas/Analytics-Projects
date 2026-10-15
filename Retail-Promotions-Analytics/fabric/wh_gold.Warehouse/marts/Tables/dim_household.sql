CREATE TABLE [marts].[dim_household] (
    [household_sk]               VARCHAR (50) NULL,
    [household_id]               INT          NULL,
    [has_demographics]           INT          NULL,
    [age_band]                   VARCHAR (50) NULL,
    [marital_status_code]        VARCHAR (50) NULL,
    [income_band]                VARCHAR (50) NULL,
    [household_size]             VARCHAR (50) NULL,
    [household_composition]      VARCHAR (50) NULL,
    [homeowner_status]           VARCHAR (50) NULL,
    [children_band]              VARCHAR (50) NULL,
    [age_band_sort]              INT          NULL,
    [income_band_sort]           INT          NULL,
    [household_size_sort]        INT          NULL,
    [household_composition_sort] INT          NULL,
    [children_band_sort]         INT          NULL,
    [first_purchase_day]         INT          NULL,
    [last_purchase_day]          INT          NULL
);


GO