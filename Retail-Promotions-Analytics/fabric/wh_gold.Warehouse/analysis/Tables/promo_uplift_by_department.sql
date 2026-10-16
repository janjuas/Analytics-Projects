CREATE TABLE [analysis].[promo_uplift_by_department] (
    [department]          VARCHAR (100)   NULL,
    [promo_type]          VARCHAR (20)    NULL,
    [product_store_pairs] INT             NULL,
    [promoted_weeks]      INT             NULL,
    [baseline_weeks]      INT             NULL,
    [avg_units_promoted]  DECIMAL (12, 4) NULL,
    [avg_units_baseline]  DECIMAL (12, 4) NULL,
    [uplift_pct]          DECIMAL (9, 4)  NULL
);


GO