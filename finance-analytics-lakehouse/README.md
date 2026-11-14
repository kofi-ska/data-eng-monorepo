# Finance Analytics Lakehouse

Azure ELT project using the 2025 EBA transparency exercise to produce five
controlled Basel III capital and credit-risk measures.

## Scope

- 119 banks in the June 2025 exercise population across 25 countries.
- Four reporting dates from September 2024 to June 2025.
- Five measures: original credit exposure, credit-risk RWA, total risk exposure
  amount, CET1 capital and CET1 ratio.
- 469 available capital records; all reconcile within one basis point.
- No dashboard, regulatory capital engine or COREP submission.

See [Basel III scope](docs/basel-iii.md) and the
[source-to-target mapping](docs/source-to-target.md).

## Deployed result

The live model produced 2,341 controlled measure rows for 120 distinct bank
LEIs across the four dates. All five finance controls passed with zero failed
records. See [validation results](docs/validation-results.md).

## Architecture

```text
EBA files -> Python download and checksum -> ADLS raw
          -> Synapse Serverless SQL views -> controlled Finance measures
```

Terraform creates one resource group, one ADLS Gen2 account with `raw`,
`curated` and `control` filesystems, and one Entra-only Synapse workspace. No
dedicated SQL or Spark pool is created.

## Local checks

```bash
python3 -m unittest discover -s tests -v
terraform -chdir=infra/azure fmt -check -recursive
terraform -chdir=infra/azure validate
```

## Plan

```bash
python3 src/deploy.py plan \
  --subscription-id e0a31fe7-668b-4aad-884c-78910bb40bce
```

Review the plan before deploying.

## Deploy infrastructure and raw data

```bash
python3 src/deploy.py apply \
  --subscription-id e0a31fe7-668b-4aad-884c-78910bb40bce
```

The workflow downloads the official EBA package, writes a SHA-256 manifest,
uploads files without overwriting existing blobs, and renders SQL with the
deployed storage-account name.

Run the rendered SQL against the built-in serverless SQL endpoint in this
order:

1. `build/sql/00_database.sql` against `master`.
2. `build/sql/staging/01_raw_views.sql` against `finance_analytics`.
3. `build/sql/curated/10_finance_measures.sql` against `finance_analytics`.
4. `build/sql/validation/20_finance_controls.sql` against `finance_analytics`.

All five validation rows must return `PASS`.

## Cleanup

```bash
terraform -chdir=infra/azure destroy \
  -var='subscription_id=e0a31fe7-668b-4aad-884c-78910bb40bce' \
  -var='client_ip=<current-public-ip>'
```

Destroying the resource group removes all uploaded data and validation
evidence. Preserve required screenshots or exported results first.
