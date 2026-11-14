/* A control passes when failed_record_count is zero. */

WITH duplicate_other AS (
    SELECT LEI_Code, Period, Item
    FROM staging.eba_other_templates
    WHERE Item IN ('2520102', '2520138', '2520140')
    GROUP BY LEI_Code, Period, Item
    HAVING COUNT(*) > 1
),
duplicate_credit AS (
    SELECT LEI_Code, Period, Item, Portfolio
    FROM staging.eba_credit_risk
    WHERE Item IN ('2520501', '2520531')
      AND Country = '0'
      AND Country_rank = '0'
      AND Exposure = '0'
      AND Status = '0'
      AND Perf_Status = '0'
      AND NACE_codes = '0'
    GROUP BY LEI_Code, Period, Item, Portfolio
    HAVING COUNT(*) > 1
),
ratio_values AS (
    SELECT
        bank_lei,
        reporting_date,
        MAX(CASE WHEN measure_code = 'CET1_CAPITAL' THEN measure_value END) AS cet1_capital,
        MAX(CASE WHEN measure_code = 'TOTAL_RISK_EXPOSURE_AMOUNT' THEN measure_value END) AS total_rwa,
        MAX(CASE WHEN measure_code = 'CET1_RATIO_PUBLISHED' THEN measure_value END) AS published_ratio
    FROM curated.finance_measures
    WHERE measure_code IN ('CET1_CAPITAL', 'TOTAL_RISK_EXPOSURE_AMOUNT', 'CET1_RATIO_PUBLISHED')
    GROUP BY bank_lei, reporting_date
),
ratio_failures AS (
    SELECT bank_lei, reporting_date
    FROM ratio_values
    WHERE total_rwa IS NULL
       OR total_rwa = 0
       OR cet1_capital IS NULL
       OR published_ratio IS NULL
       OR ABS((cet1_capital / total_rwa) - published_ratio) > 0.0001
),
credit_component_failures AS (
    SELECT bank_lei, reporting_date
    FROM curated.finance_measures
    WHERE measure_code = 'CREDIT_RISK_RWA'
      AND source_component_count <> 2
),
aggregate_leaks AS (
    SELECT bank_lei, reporting_date, measure_code
    FROM curated.finance_measures
    WHERE bank_lei = 'xxxxxxxxxxxxxxxxxxxx'
)
SELECT
    control_name,
    failed_record_count,
    CASE WHEN failed_record_count = 0 THEN 'PASS' ELSE 'FAIL' END AS control_status
FROM (
    SELECT 'DUPLICATE_OTHER_MEASURE' AS control_name, COUNT_BIG(*) AS failed_record_count FROM duplicate_other
    UNION ALL
    SELECT 'DUPLICATE_CREDIT_COMPONENT', COUNT_BIG(*) FROM duplicate_credit
    UNION ALL
    SELECT 'CET1_RATIO_RECONCILIATION', COUNT_BIG(*) FROM ratio_failures
    UNION ALL
    SELECT 'CREDIT_RWA_COMPONENT_COUNT', COUNT_BIG(*) FROM credit_component_failures
    UNION ALL
    SELECT 'ALL_OTHER_BANKS_EXCLUDED', COUNT_BIG(*) FROM aggregate_leaks
) AS controls
ORDER BY control_name;
