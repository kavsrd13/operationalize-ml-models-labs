# MedTriage fine-tuning automation

This exercise runs a supervised fine-tuning job only after versioned data and configuration are pushed to `main`. GitHub Actions signs in with OpenID Connect, validates the dataset, runs a small baseline evaluation, uploads the JSONL files, and submits a Foundry job. No API key is stored in GitHub or committed to the repository.

## Dataset analysis

The source filenames contain `300`, but the actual split is **255 training examples** and **45 validation examples**. Both files passed the structural SFT validator and use one shared system prompt. The custom validator also checks the output JSON schema, allowed urgency values, and train/validation question overlap.

The task is supervised fine-tuning for reliable JSON formatting and triage routing. It is not a clinical decision support system. The source prompt itself says training demonstration only. A qualified clinical reviewer must confirm the labels, escalation wording, intended jurisdiction, and absence of personal health information before enabling the job. The repository gates submission with `MEDTRIAGE_DATA_REVIEWED=true` for that reason.

The workflow baselines the `medtriage-base` deployment against ten held-out validation examples before training. It records JSON-schema compliance and urgency-label match rate. Compare those metrics with a fine-tuned deployment after the job completes; do not assume that the fine-tuned final checkpoint is better without that comparison.

## One-time setup

The target is the Pay-As-You-Go subscription `2df30ff1-915d-4d35-974a-3d3155aaa413` in East US. It has available `gpt-4o-mini` base and fine-tuning capacity. Sign in to the tenant that owns that subscription, then run this from the repository root:

```powershell
az login --tenant cabf5d06-7e3a-4d14-b7f4-2b5819ed881e --use-device-code
az account set --subscription 2df30ff1-915d-4d35-974a-3d3155aaa413
.\finetunning\setup.ps1 -PreviewOnly
.\finetunning\setup.ps1
```

The setup script first asks whether to use an existing Azure AI Services/Azure OpenAI resource or create a new dedicated resource. When **Existing** is selected, it lists compatible resources in the selected subscription and asks for a number. It reuses a compatible `medtriage-base` deployment or creates it when missing; it does not recreate or retag the selected resource. When **New** is selected, it creates the resource group and Azure AI Services resource as before.

Both choices create a GitHub managed identity, an OIDC trust restricted to this repository’s `main` branch, and the least-privilege `Cognitive Services OpenAI Contributor` assignment on the selected resource. The script sets GitHub Actions secrets and variables but leaves training disabled.

For unattended or repeatable setup, pass the choice explicitly:

```powershell
# Create a new resource
.\finetunning\setup.ps1 -ResourceMode New -Yes

# Reuse a known resource
.\finetunning\setup.ps1 -ResourceMode Existing `
  -ResourceGroup '<existing-resource-group>' `
  -AccountName '<existing-account-name>' `
  -Yes
```

## Trigger a reviewed training run

After clinical/data review, set both GitHub repository variables to `true`:

```powershell
gh variable set MEDTRIAGE_DATA_REVIEWED --body true --repo kavsrd13/operationalize-ml-models-labs
gh variable set ENABLE_MEDTRIAGE_FINETUNING --body true --repo kavsrd13/operationalize-ml-models-labs
```

Then edit `config/finetune.json` or replace a JSONL file, commit and push to `main`. The `Fine-tune MedTriage model` workflow starts automatically. It records the submitted Foundry job ID in the GitHub run summary and uploads `fine_tuning_job.json` as a workflow artifact.

To avoid accidental paid jobs, set `ENABLE_MEDTRIAGE_FINETUNING` back to `false` after submission.

## Files

- `data/`: versioned SFT train and validation files.
- `config/finetune.json`: base model, training tier, epochs, learning rate, and model suffix.
- `scripts/validate_dataset.py`: deterministic JSONL and label validation.
- `scripts/evaluate_baseline.py`: ten-example base-model baseline.
- `scripts/submit_finetune.py`: token-based upload and fine-tuning submission.
- `infra/`: Bicep infrastructure with GitHub OIDC.
- `setup.ps1`: guided deployment and GitHub configuration.
