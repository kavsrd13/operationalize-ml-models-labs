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

## Live validation boundary

The Exercise 12 revision has not submitted a new paid fine-tuning job. A learner or instructor must still validate the selected subscription's current quota and regional model availability, deploy or select the Azure AI resource, complete GitHub OIDC authentication, observe the baseline request, submit the job, and monitor it to a terminal state. A submitted job is not evidence that the fine-tuned model is safe or better than the base model.
