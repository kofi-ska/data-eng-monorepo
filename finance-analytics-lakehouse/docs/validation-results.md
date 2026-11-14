# Validation results

Run against the deployed Synapse serverless model on 14 November 2026.

- 2,341 curated measure rows
- 120 distinct bank LEIs across four reporting dates
- 469 CET1 capital, CET1 ratio and total-risk-exposure records
- 467 original-credit-exposure and credit-risk-RWA records
- 5 finance controls passed; 0 failed records

| Control | Failed records | Result |
|---|---:|---|
| Aggregate bank excluded | 0 | PASS |
| CET1 ratio reconciles within 1 bp | 0 | PASS |
| Credit-risk RWA has two components | 0 | PASS |
| Duplicate credit components | 0 | PASS |
| Duplicate other measures | 0 | PASS |

The validation scan read 569 MB from ADLS Gen2. Synapse wrote no data.
