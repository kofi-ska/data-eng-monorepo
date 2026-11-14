# Basel III scope

## What we are analysing

The project uses the 2025 EBA transparency exercise to compare published
capital and credit-risk measures by bank and reporting date.

Dataset scope:

- 119 banks in 25 countries;
- four reporting dates from September 2024 to June 2025;
- amounts reported in EUR millions;
- 469 bank-period records available for the selected capital measures.

## Measures

| Measure | EBA item | Treatment |
| --- | ---: | --- |
| Original credit exposure | `2520501` | Use the published combined SA and IRB total |
| Credit-risk RWA | `2520531` | Add the SA and IRB rows |
| Total risk exposure amount | `2520138` | Use as the CET1-ratio denominator |
| CET1 capital | `2520102` | Use the transitional reported amount |
| CET1 ratio | `2520140` | Retain the published ratio and derive it independently |

The reconciliation is:

```text
CET1 capital / total risk exposure amount = CET1 ratio
```

All 469 available records reconcile within one basis point. This becomes an
automated control in the ELT pipeline.

## Regulatory break

CRR3 applied from 1 January 2025. It changed parts of the credit-risk and
risk-weighted-asset calculations and introduced the output floor.

| Period | Basis |
| --- | --- |
| September 2024 | Pre-CRR3 |
| December 2024 | Pre-CRR3 |
| March 2025 | CRR3 transitional |
| June 2025 | CRR3 transitional |

The December-to-March change cannot be presented as a normal quarterly
movement without flagging the regulatory change. Each curated record will
therefore include `regulatory_basis`.

## Finance controls

The pipeline will enforce five controls:

1. No duplicate record for bank, period, measure and portfolio.
2. Every amount retains its EBA file, item, sheet, row and column.
3. Derived CET1 ratio must match the published ratio within one basis point.
4. Missing observations remain null; they are never converted to zero.
5. The EBA `All other banks` aggregate is excluded from bank totals to prevent
   double counting.

Ratios are not additive. A country-level CET1 ratio must be calculated as:

```text
sum(CET1 capital) / sum(total risk exposure amount)
```

## Boundary

This is an analytics pipeline. It does not calculate regulatory capital,
reproduce the CRR3 output floor, assess compliance or produce COREP returns.

Sources: [EBA transparency exercise](https://www.eba.europa.eu/risk-and-data-analysis/risk-analysis/eu-wide-transparency-exercise),
[Basel Framework](https://www.bis.org/committees/bcbs/basel-framework/standard/rbc?allChapters=true),
and [Regulation (EU) 2024/1623](https://eur-lex.europa.eu/eli/reg/2024/1623/oj).
