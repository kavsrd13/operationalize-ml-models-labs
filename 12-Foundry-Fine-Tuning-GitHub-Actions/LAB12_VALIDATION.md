# Exercise 12 validation record

## Completed offline checks

- Training dataset parsed: 255 records.
- Validation dataset parsed: 45 records.
- Required `system`, `user`, `assistant` structure passed.
- Assistant JSON schema and allowed urgency labels passed.
- Identical user-question overlap across splits: zero.
- Python scripts compile locally.
- The configuration validator separates `GlobalStandard` placement from the SFT hyperparameters `n_epochs`, `batch_size` and `learning_rate_multiplier`.
- The SDK request-shape test verifies hyperparameters are nested under `method.supervised.hyperparameters`, while `seed`, `suffix` and `trainingType` remain job controls.
- `azure-ai-projects` 2.8.0, `azure-identity` 1.25.3 and `openai` 3.13.0 are pinned for repeatable GitHub execution.
- The GitHub managed identity has `Foundry User` at `proj-default` scope. GitHub OIDC sign-in succeeded without a stored Azure password or client secret.
- `MEDTRIAGE_FOUNDRY_PROJECT_ENDPOINT` is configured as `https://Finetunning121.services.ai.azure.com/api/projects/proj-default`.
- The reusable `medtriage-base` deployment is healthy at 10K TPM. Bicep preserves the existing content-safety policy and model-upgrade setting.
- The workflow trigger covers all committed changes under `data/**` and `config/**`; dataset filenames are resolved at runtime instead of being hardcoded in the workflow.
- The Azure job is guarded by the canonical repository name, so pushes in public forks cannot attempt to use upstream OIDC settings or Azure configuration.
- GitHub workflow YAML parses locally.
- PowerShell setup script parses locally.
- New-resource and existing-resource Bicep entry points compile locally.
- On 12 November 2026, the new-resource subscription-level `what-if` succeeded in East US with `gpt-4.1-mini` version `2025-04-14`, Global Standard capacity 10, the Azure AI Services account, managed identity, OIDC federation and scoped role assignment.
- The selected subscription reported 5,000K Global Standard base quota and 500K Global Standard fine-tuning quota for `gpt-4.1-mini` in East US.
- A live resource query found one successful older job based on `gpt-4o-mini-2024-07-18`. Its fine-tuned deployment quota is 0K TPM for both Global Standard and Data Zone Standard in East US and the other checked candidate regions, so it must not be used for this exercise.

## Live GitHub and Foundry validation

- GitHub Actions run [43214872121](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/43214872121) passed configuration validation, dataset validation, GitHub OIDC sign-in, dependency installation, and the ten-example base-model evaluation.
- The Azure AI Projects SDK uploaded both files and successfully called `fine_tuning.jobs.create()`.
- Foundry created job `ftjob-aaf5e5515f784084aeb2c2b32e98b634` for `gpt-4.1-mini-2025-04-14` on 12 November 2026.
- At the time this record was updated, the job status was `pending` with no reported error and the GitHub workflow was monitoring it.

Job creation proves that the automated identity, project endpoint, file upload, dataset processing, and SDK request shape work together. It does not prove that the resulting model is better or safe to deploy. After training, the instructor must compare checkpoints and held-out behavior with the baseline before approving deployment.
