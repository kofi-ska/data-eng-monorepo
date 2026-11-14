# Source-to-target mapping

## Reporting grain

The curated view contains one row per:

```text
bank LEI + reporting date + measure code
```

The EBA aggregate identified by `xxxxxxxxxxxxxxxxxxxx` is excluded. It is not
a bank and would double count institutions already represented in the data.

## Mapping

| Curated measure | Source | Item | Rule |
| --- | --- | ---: | --- |
| `ORIGINAL_CREDIT_EXPOSURE` | `tr_cre.csv` | `2520501` | Select the combined SA and IRB total row |
| `CREDIT_RISK_RWA` | `tr_cre.csv` | `2520531` | Sum portfolio `1` (SA) and portfolio `2` (IRB) |
| `TOTAL_RISK_EXPOSURE_AMOUNT` | `tr_oth.csv` | `2520138` | Select the published total |
| `CET1_CAPITAL` | `tr_oth.csv` | `2520102` | Select the transitional reported amount |
| `CET1_RATIO_PUBLISHED` | `tr_oth.csv` | `2520140` | Preserve as a decimal ratio |

All monetary values use `DECIMAL(28,10)` and retain their published unit of
EUR millions. Ratios use the same fixed-precision type and are not additive.

## Period treatment

`Period` is converted from `YYYYMM` to the corresponding month-end date.
September and December 2024 are labelled `PRE_CRR3`. March and June 2025 are
labelled `CRR3_TRANSITIONAL`.

## Required controls

The validation query reports five results:

- duplicate capital-measure keys;
- duplicate credit-risk component keys;
- CET1 ratio differences greater than one basis point;
- credit-risk RWA records without exactly two source components;
- accidental inclusion of the EBA aggregate.

Every result must be `PASS` before the curated data is published.
