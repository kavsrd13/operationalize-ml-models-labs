# Lab 11 validation - 13 November 2026

## Architecture trace

- Bicep creates 10 ARM resources: resource group, storage account, key vault,
  Log Analytics workspace, Application Insights, Azure ML workspace,
  `course-cpu` AML compute cluster, `id-course-github` user-assigned identity,
  `github-main` federated credential, and an AzureML Data Scientist role
  assignment scoped to the workspace.
- No compute instance and no dedicated container registry are declared.
- After Bicep deployment, `setup.ps1` extracts nine CSVs from the tracked Olist
  ZIP and registers `olist-ecommerce-raw:1` as a `uri_folder` in the same
  workspace.
- Setup writes three OIDC identifiers as GitHub secrets and four non-secret
  Azure ML settings as repository variables.
- `.github/workflows/train-freight.yml` checks the workspace, selected compute,
  and data asset before submitting the command job. The submitted compute is
  the checked `AZURE_ML_COMPUTE` value; setup sets it to `course-cpu`.
- The job mounts `olist-ecommerce-raw:1` read-only on the training node and runs
  `src/train.py` in curated environment `sklearn-1.5:54`.

## Checks completed

- Bicep compiled successfully with Azure CLI 2.90.0 and Bicep 0.46.1.
- PowerShell parsed `setup.ps1` without syntax errors.
- Both workflow and job YAML parsed successfully.
- Training and bootstrap Python files compiled successfully.
- A live Azure what-if against teaching subscription
  `42848f6c-f0f7-4143-b9d3-76441ceeda99` in East US succeeded and reported
  exactly the 10 expected create operations. What-if created no resources.
- East US showed 20 Standard EDSv4-family vCPUs available and zero in use;
  `course-cpu` needs four while its single node is running.
- Azure ML registry lookup confirmed curated environment
  `sklearn-1.5`, version `54`, with Linux OS exists.
- Fresh bootstrap extraction verified exactly nine nonempty original CSVs.
- A full-data local smoke run processed 112,650 rows, split them into 91,231
  training and 21,419 test rows, trained all three candidates with
  `max_iter=2`, produced metrics and feature importance, and saved/logged the
  MLflow model. Eight output files were produced.
- The generated student HTML was rebuilt from the corrected Markdown guide.
- Git whitespace validation passed.

## Issues corrected in this review

- Replaced the obsolete client-secret/manual-workflow instructions with the
  implemented OIDC and push-triggered workflow.
- Removed the redundant `.github/workflows/manual-trigger-job.yml`; the
  canonical `train-freight.yml` already supports push and manual execution.
- Fixed the submission step so it uses the trimmed resource group, workspace,
  and compute values that passed preflight instead of reintroducing raw GitHub
  variables.
- Limited automatic training triggers to Lab 11 job or source changes, so
  documentation and workflow-maintenance commits do not start billable jobs.
- Added explicit resource outputs and setup reporting for every important
  resource name.
- Added numbered subscription selection, repository detection from `origin`,
  current-branch validation, and required resource-provider registration.
- Documented the exact resource inventory, data files, mounted asset, compute
  target, environment, model outputs, and verification steps.

## Live-validation boundary

This review did not deploy the 10 resources, change GitHub secrets/variables,
or submit a billable Azure ML job. Bicep compilation, Azure what-if, quota,
curated-environment lookup, and the complete local data/training path passed.
The final repository-specific proof still requires a learner to run
`setup.ps1` in their own fork, push the hyperparameter change, and observe one
completed GitHub-to-Azure training job.
