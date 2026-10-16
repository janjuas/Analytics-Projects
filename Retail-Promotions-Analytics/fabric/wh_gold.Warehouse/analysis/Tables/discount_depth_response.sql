CREATE TABLE [analysis].[discount_depth_response] (
    [department]               VARCHAR (100)   NULL,
    [commodity]                VARCHAR (100)   NULL,
    [discount_depth_band]      VARCHAR (20)    NULL,
    [discount_depth_band_sort] INT             NULL,
    [lines]                    INT             NULL,
    [units]                    INT             NULL,
    [avg_units_per_line]       DECIMAL (12, 4) NULL,
    [avg_shelf_unit_price]     DECIMAL (12, 4) NULL,
    [avg_paid_unit_price]      DECIMAL (12, 4) NULL,
    [units_share_of_commodity] DECIMAL (9, 4)  NULL
);


GO