IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'curated')
    EXEC('CREATE SCHEMA curated');
GO

CREATE OR ALTER VIEW curated.finance_measures
AS
WITH other_measures AS (
    SELECT
        LEI_Code AS bank_lei,
        NSA AS bank_country_code,
        EOMONTH(DATEFROMPARTS(LEFT(Period, 4), RIGHT(Period, 2), 1)) AS reporting_date,
        CASE WHEN Period < '202501' THEN 'PRE_CRR3' ELSE 'CRR3_TRANSITIONAL' END AS regulatory_basis,
        CASE Item
            WHEN '2520102' THEN 'CET1_CAPITAL'
            WHEN '2520138' THEN 'TOTAL_RISK_EXPOSURE_AMOUNT'
            WHEN '2520140' THEN 'CET1_RATIO_PUBLISHED'
        END AS measure_code,
        CASE Item
            WHEN '2520102' THEN 'CET1 capital'
            WHEN '2520138' THEN 'Total risk exposure amount'
            WHEN '2520140' THEN 'Published CET1 ratio'
        END AS measure_name,
        TRY_CONVERT(DECIMAL(28, 10), Amount) AS measure_value,
        CASE WHEN Item = '2520140' THEN 'ratio' ELSE 'EUR million' END AS unit,
        'tr_oth.csv' AS source_file,
        Item AS source_item,
        CAST(1 AS INT) AS source_component_count
    FROM staging.eba_other_templates
    WHERE Item IN ('2520102', '2520138', '2520140')
      AND LEI_Code <> 'xxxxxxxxxxxxxxxxxxxx'
),
credit_exposure AS (
    SELECT
        LEI_Code AS bank_lei,
        NSA AS bank_country_code,
        EOMONTH(DATEFROMPARTS(LEFT(Period, 4), RIGHT(Period, 2), 1)) AS reporting_date,
        CASE WHEN Period < '202501' THEN 'PRE_CRR3' ELSE 'CRR3_TRANSITIONAL' END AS regulatory_basis,
        'ORIGINAL_CREDIT_EXPOSURE' AS measure_code,
        'Original credit exposure' AS measure_name,
        TRY_CONVERT(DECIMAL(28, 10), Amount) AS measure_value,
        'EUR million' AS unit,
        'tr_cre.csv' AS source_file,
        Item AS source_item,
        CAST(1 AS INT) AS source_component_count
    FROM staging.eba_credit_risk
    WHERE Item = '2520501'
      AND Portfolio = '1'
      AND Country = '0'
      AND Country_rank = '0'
      AND Exposure = '0'
      AND Status = '0'
      AND Perf_Status = '0'
      AND NACE_codes = '0'
      AND LEI_Code <> 'xxxxxxxxxxxxxxxxxxxx'
),
credit_rwa AS (
    SELECT
        LEI_Code AS bank_lei,
        NSA AS bank_country_code,
        EOMONTH(DATEFROMPARTS(LEFT(Period, 4), RIGHT(Period, 2), 1)) AS reporting_date,
        CASE WHEN Period < '202501' THEN 'PRE_CRR3' ELSE 'CRR3_TRANSITIONAL' END AS regulatory_basis,
        'CREDIT_RISK_RWA' AS measure_code,
        'Credit-risk RWA' AS measure_name,
        SUM(TRY_CONVERT(DECIMAL(28, 10), Amount)) AS measure_value,
        'EUR million' AS unit,
        'tr_cre.csv' AS source_file,
        Item AS source_item,
        COUNT(*) AS source_component_count
    FROM staging.eba_credit_risk
    WHERE Item = '2520531'
      AND Portfolio IN ('1', '2')
      AND Country = '0'
      AND Country_rank = '0'
      AND Exposure = '0'
      AND Status = '0'
      AND Perf_Status = '0'
      AND NACE_codes = '0'
      AND LEI_Code <> 'xxxxxxxxxxxxxxxxxxxx'
    GROUP BY LEI_Code, NSA, Period, Item
)
SELECT * FROM other_measures
UNION ALL
SELECT * FROM credit_exposure
UNION ALL
SELECT * FROM credit_rwa;
GO
