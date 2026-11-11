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

After explicit approval, a temporary Entra application received **AzureML Data
Scientist** only on `AzureML/MachineLearn123`. Its GitHub federated credential
trusted this repository's `main` branch. Three manual runs found and fixed two
real integration issues:

1. [Run 42960837820](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/42960837820)
   failed OIDC sign-in. New GitHub repositories use an immutable subject with
   owner and repository IDs; the original name-only subject did not match.
   Exercise 11 now builds the ID-based subject. See the
   [GitHub OIDC reference](https://docs.github.com/en/actions/reference/security/oidc).
2. [Run 42961001284](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/42961001284)
   passed OIDC and resource checks and submitted Azure job
   `dynamic_lamp_l16bxv3m3b`, which **Completed**. The workflow itself failed
   because `az ml job stream` returned `Incorrect padding` during finalization;
   it checked status before Azure reported the terminal state.
3. The workflow was changed to poll Azure ML status directly, with a 60-minute
   bound. [Run 42961914658](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/42961914658)
   finished **success**: OIDC sign-in, CLI install, shared-resource checks,
   job submission, and final `Completed` check all passed. Its Azure job
   `polite_hat_dw0yh6gkjj` **Completed** on `olist-course-cpu`. Downloaded
   artifacts contain `outputs/model/MLmodel` and `outputs/metrics.json`;
   boosting MAE was 5.4856 BRL versus 9.7709 BRL for the median baseline.

After the successful test, the training gate was disabled. All three temporary
GitHub secrets and all three repository variables were deleted; both GitHub
lists returned empty. The temporary workspace role assignment, service
principal, and Entra application were deleted. The role and app lists returned
empty. The test cluster was deleted; `az ml compute list` returned only the
pre-existing `krishnacompute` instance. Existing workspace assets were left
in place. Clients must configure their own GitHub OIDC identity and
repository settings to run the workflow.

The revised shared-compute definitions for exercises 04–07 and 09–10 passed
Azure ML SDK `load_job` checks, but have not been rerun live after the naming
change. Earlier live results for those labs are recorded in
`AZURE_VALIDATION_2026-11-10.md`.
