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
- Student instructions now use **Use this template**. `setup.ps1` checks existing Azure CLI and GitHub CLI sessions, detects the student repository from `origin`, and configures repository-specific OIDC trust, Actions secrets, and variables.
- The setup script enables GitHub Actions and the Exercise 12 workflow in the student repository after Azure deployment and GitHub configuration succeed. Exiting at the resource-mode or Bicep-preview prompt leaves GitHub Actions settings unchanged.
- GitHub workflow YAML parses locally.
- PowerShell setup script parses locally.
- New-resource and existing-resource Bicep entry points compile locally.
- On 12 November 2026, the new-resource subscription-level `what-if` succeeded in East US with `gpt-4.1-mini` version `2025-04-14`, Global Standard capacity 10, the Azure AI Services account, managed identity, OIDC federation and scoped role assignment.
- The selected subscription reported 5,000K Global Standard base quota and 500K Global Standard fine-tuning quota for `gpt-4.1-mini` in East US.
- A live resource query found one successful older job based on `gpt-4o-mini-2024-07-18`. Its fine-tuned deployment quota is 0K TPM for both Global Standard and Data Zone Standard in East US and the other checked candidate regions, so it must not be used for this exercise.
- On 13 November 2026, a new-resource run in `rg-medtriage-finetuning` created account `medtriageft985272` and its `medtriage-base` deployment, but parallel project creation failed with `RequestConflict` on the account. Both Bicep paths now make project creation depend on the baseline deployment when one is needed. The compiled templates contain this dependency. An existing-resource recovery deployment then created `medtriage-project` and its project-scoped role successfully without creating another account or baseline deployment. The corrected new-resource path has not been live-tested on another new account.

## Live GitHub and Foundry validation

- GitHub Actions run [43214872121](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/43214872121) passed configuration validation, dataset validation, GitHub OIDC sign-in, dependency installation, and the ten-example base-model evaluation.
- The Azure AI Projects SDK uploaded both files and successfully called `fine_tuning.jobs.create()`.
- Foundry created job `ftjob-aaf5e5515f784084aeb2c2b32e98b634` for `gpt-4.1-mini-2025-04-14` on 12 November 2026.
- At the time this record was updated, the job status was `pending` with no reported error and the GitHub workflow was monitoring it.

Job creation proves that the automated identity, project endpoint, file upload, dataset processing, and SDK request shape work together. It does not prove that the resulting model is better or safe to deploy. After training, the instructor must compare checkpoints and held-out behavior with the baseline before approving deployment.

## Portal deployment and playground boundary

The student guide now includes checkpoint selection, Serverless deployment,
Foundry playground system instructions, three unseen test prompts, a base-versus-
fine-tuned comparison, and serving-deployment cleanup. These steps follow the
current Microsoft Foundry deployment and playground documentation. They were
not executed live in this validation record because deployment depends on the
learner's current fine-tuned-model quota and deployment permissions.
