# Exercise 12 validation record

## Completed offline checks

- Training dataset parsed: 255 records.
- Validation dataset parsed: 45 records.
- Required `system`, `user`, `assistant` structure passed.
- Assistant JSON schema and allowed urgency labels passed.
- Identical user-question overlap across splits: zero.
- Python scripts compile locally.
- GitHub workflow YAML parses locally.
- PowerShell setup script parses locally.
- New-resource and existing-resource Bicep entry points compile locally.
- On 12 November 2026, the new-resource subscription-level `what-if` succeeded in East US with `gpt-4.1-mini` version `2025-04-14`, Global Standard capacity 1, the Azure AI Services account, managed identity, OIDC federation and scoped role assignment.
- The selected subscription reported 5,000K Global Standard base quota and 500K Global Standard fine-tuning quota for `gpt-4.1-mini` in East US.

## Live validation boundary

The Exercise 12 revision has not submitted a new paid fine-tuning job. The successful `what-if` created no resources. A learner or instructor must still deploy or select the Azure AI resource, complete GitHub OIDC authentication, observe the baseline request, submit the job, and monitor it to a terminal state. Quota and model lifecycle must be rechecked in each learner subscription. A submitted job is not evidence that the fine-tuned model is safe or better than the base model.
