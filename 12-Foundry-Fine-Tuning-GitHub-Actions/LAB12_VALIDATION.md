# Exercise 12 validation record

## Completed offline checks

- Training dataset parsed: 255 records.
- Validation dataset parsed: 45 records.
- Required `system`, `user`, `assistant` structure passed.
- Assistant JSON schema and allowed urgency labels passed.
- Identical user-question overlap across splits: zero.
- Python scripts compile locally.
- The configuration validator pins `gpt-4.1-mini-2025-04-14` and `globalStandard` training before any Azure upload.
- GitHub workflow YAML parses locally.
- PowerShell setup script parses locally.
- New-resource and existing-resource Bicep entry points compile locally.
- On 12 November 2026, the new-resource subscription-level `what-if` succeeded in East US with `gpt-4.1-mini` version `2025-04-14`, Global Standard capacity 1, the Azure AI Services account, managed identity, OIDC federation and scoped role assignment.
- The selected subscription reported 5,000K Global Standard base quota and 500K Global Standard fine-tuning quota for `gpt-4.1-mini` in East US.
- A live resource query found one successful older job based on `gpt-4o-mini-2024-07-18`. Its fine-tuned deployment quota is 0K TPM for both Global Standard and Data Zone Standard in East US and the other checked candidate regions, so it must not be used for this exercise.

## Live validation boundary

The Exercise 12 revision has not submitted a new paid `gpt-4.1-mini` fine-tuning job. A learner must push reviewed data and the pinned configuration, monitor the job to a terminal state, compare it with the baseline, and obtain instructor approval before deployment. Quota and model lifecycle must be rechecked in each learner subscription. A submitted or succeeded job is not evidence that the fine-tuned model is safe or better than the base model.
