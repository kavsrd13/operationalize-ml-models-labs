# Shared compute and GitHub validation — 11 November 2026

## Live Azure ML training

The updated exercise 03 YAML submitted to the preserved West US workspace
`AzureML/MachineLearn123` using the new shared `olist-course-cpu` cluster and
existing `olist-ecommerce-raw:1` data asset. Job `frank_cat_h1f5qfxq8y`
finished **Completed** on that cluster. Downloaded job artifacts contained
`outputs/model/MLmodel`, `outputs/metrics.json`, and training logs.

| Model | Held-out MAE (BRL) | Held-out RMSE (BRL) |
| --- | ---: | ---: |
| Median baseline | 9.7709 | 19.8673 |
| Linear | 6.1179 | 12.7865 |
| Gradient boosting | 5.4856 | 11.9086 |

The local Azure CLI `job stream` command returned `binascii.Error: Incorrect
padding` after the job reached Finalizing. This was a log-stream client error:
`az ml job show` reported `Completed`, and `az ml job download --all` retrieved
the full logs, metrics, plots, and MLflow model. Exercise 03 now documents the
fallback.

The validation cluster was created with `min_instances: 0`, `max_instances: 1`,
then deleted after the run. `az ml compute list` returned only the pre-existing
`krishnacompute` instance. The existing workspace was left in place.

## GitHub publication and automation

The client collection is published in the private repository
`kavsrd13/operationalize-ml-models-labs` at commit `b7ffe38` or later. GitHub
fetched `index.html` and `.github/workflows/train-freight.yml` successfully.
GitHub recognized the workflow. Its initial `push` run was **skipped** because
`ENABLE_AZURE_TRAINING` was unset, so publication did not launch a billable job.

The workflow's OIDC sign-in and Azure job submission have **not** yet run.
Automatic approval review rejected creation of the temporary Entra application
needed to grant the workflow workspace access. The rejection reason was its
persistent security and access implications without specific authorization.
No Entra app, role assignment, or GitHub repository credentials were created for
this test. The workflow's YAML and Azure ML job reference passed local parsing.

The revised shared-compute definitions for exercises 04–07 and 09–10 passed
Azure ML SDK `load_job` checks, but have not been rerun live after the naming
change. Earlier live results for those labs are recorded in
`AZURE_VALIDATION_2026-11-10.md`.
