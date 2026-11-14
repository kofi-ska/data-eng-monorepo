/*
Replace <storage-account-name> after Terraform deployment.
Queries run in a Synapse serverless SQL database using the caller's Entra ID.
*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

CREATE OR ALTER VIEW staging.eba_other_templates
AS
SELECT
    source.LEI_Code,
    source.NSA,
    source.Period,
    source.Item,
    source.Label,
    source.ASSETS_FV,
    source.ASSETS_Stages,
    source.Exposure,
    source.Financial_instruments,
    source.Amount,
    source.Fin_end_year,
    source.n_quarters,
    source.[Row] AS source_row,
    source.[Column] AS source_column,
    source.Sheet AS source_sheet
FROM OPENROWSET(
    BULK 'https://<storage-account-name>.dfs.core.windows.net/raw/eba/transparency-exercise/2025/tr_oth.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
)
WITH (
    LEI_Code VARCHAR(20),
    NSA VARCHAR(2),
    Period CHAR(6),
    Item VARCHAR(10),
    Label VARCHAR(500),
    ASSETS_FV VARCHAR(10),
    ASSETS_Stages VARCHAR(10),
    Exposure VARCHAR(10),
    Financial_instruments VARCHAR(10),
    Amount VARCHAR(50),
    Fin_end_year VARCHAR(10),
    n_quarters VARCHAR(10),
    [Row] VARCHAR(10),
    [Column] VARCHAR(10),
    Sheet VARCHAR(100)
) AS source;
GO

CREATE OR ALTER VIEW staging.eba_credit_risk
AS
SELECT
    source.LEI_Code,
    source.NSA,
    source.Period,
    source.Item,
    source.Label,
    source.Portfolio,
    source.Country,
    source.Country_rank,
    source.Exposure,
    source.Status,
    source.Perf_Status,
    source.NACE_codes,
    source.Amount,
    source.[Row] AS source_row,
    source.[Column] AS source_column,
    source.Sheet AS source_sheet
FROM OPENROWSET(
    BULK 'https://<storage-account-name>.dfs.core.windows.net/raw/eba/transparency-exercise/2025/tr_cre.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
)
WITH (
    LEI_Code VARCHAR(20),
    NSA VARCHAR(2),
    Period CHAR(6),
    Item VARCHAR(10),
    Label VARCHAR(500),
    Portfolio VARCHAR(10),
    Country VARCHAR(10),
    Country_rank VARCHAR(10),
    Exposure VARCHAR(10),
    Status VARCHAR(10),
    Perf_Status VARCHAR(10),
    NACE_codes VARCHAR(10),
    Amount VARCHAR(50),
    [Row] VARCHAR(10),
    [Column] VARCHAR(10),
    Sheet VARCHAR(100)
) AS source;
GO
