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
- The existing project endpoint `https://finetunning121.services.ai.azure.com/api/projects/proj-default` responded through `AIProjectClient`; the signed-in human identity was correctly denied because Azure Owner does not grant Foundry data-plane fine-tuning permissions.
- The existing-resource Azure what-if accepted a single least-privilege change: assign `Foundry User` to the GitHub managed identity at `proj-default` scope. It predicted no account, project, deployment, identity or federation replacement.
- The workflow trigger covers all committed changes under `data/**` and `config/**`; dataset filenames are resolved at runtime instead of being hardcoded in the workflow.
- The Azure job is guarded by the canonical repository name, so pushes in public forks cannot attempt to use upstream OIDC settings or Azure configuration.
- GitHub workflow YAML parses locally.
- PowerShell setup script parses locally.
- New-resource and existing-resource Bicep entry points compile locally.
- On 12 November 2026, the new-resource subscription-level `what-if` succeeded in East US with `gpt-4.1-mini` version `2025-04-14`, Global Standard capacity 1, the Azure AI Services account, managed identity, OIDC federation and scoped role assignment.
- The selected subscription reported 5,000K Global Standard base quota and 500K Global Standard fine-tuning quota for `gpt-4.1-mini` in East US.
- A live resource query found one successful older job based on `gpt-4o-mini-2024-07-18`. Its fine-tuned deployment quota is 0K TPM for both Global Standard and Data Zone Standard in East US and the other checked candidate regions, so it must not be used for this exercise.

## Live validation boundary

The SDK revision has not yet submitted a new paid `gpt-4.1-mini` fine-tuning job. Applying the project-scoped role and publishing the changed configuration require explicit approval because the push immediately starts paid training. After training, the learner must compare checkpoints and held-out behavior with the baseline and obtain instructor approval before deployment. A submitted or succeeded job is not evidence that the fine-tuned model is safe or better than the base model.
