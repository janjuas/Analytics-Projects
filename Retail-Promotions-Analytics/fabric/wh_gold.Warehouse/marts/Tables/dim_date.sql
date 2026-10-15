CREATE TABLE [marts].[dim_date] (
    [date_key]                 INT          NULL,
    [day_number]               INT          NULL,
    [calendar_date]            DATE         NULL,
    [week_number]              INT          NULL,
    [week_start_date]          DATE         NULL,
    [day_of_week_number]       INT          NULL,
    [day_of_week_name]         VARCHAR (10) NULL,
    [is_weekend]               INT          NULL,
    [month_number]             INT          NULL,
    [month_name]               VARCHAR (10) NULL,
    [quarter_number]           INT          NULL,
    [calendar_year]            INT          NULL,
    [study_year]               INT          NULL,
    [is_in_transaction_window] INT          NULL
);


GO