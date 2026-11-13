# Exercise 12: Foundry fine-tuning with GitHub Actions

This standalone exercise validates a versioned MedTriage supervised fine-tuning dataset, establishes passwordless GitHub-to-Azure authentication with OIDC, measures a `gpt-4.1-mini` baseline, and runs a Microsoft Foundry fine-tuning job through the Azure AI Projects SDK.

Open [Instruction/README.md](Instruction/README.md) for the editable student guide or [Instruction/index.html](Instruction/index.html) for the generated offline page.

## Folder map

- `data/`: 255 training and 45 validation JSONL records.
- `config/finetune.json`: versioned model and hyperparameter choices; optional dataset paths can disambiguate multiple JSONL files.
- `scripts/validate_dataset.py`: free structural and label validation.
- `scripts/validate_config.py`: blocks unsupported model or training choices before Azure access.
- `scripts/foundry_sdk.py`: shared `AIProjectClient` and Entra authentication setup.
- `scripts/evaluate_baseline.py`: held-out base-model baseline through the project client.
- `scripts/submit_finetune.py`: SDK upload and SFT job submission with correctly nested hyperparameters.
- `scripts/monitor_finetune.py`: terminal-state monitoring and checkpoint collection.
- `scripts/test_deployment.py`: local OpenAI Responses API test for the deployed fine-tuned model.
- `tests/`: offline assertions for the exact SDK request shape.
- `infra/`: separate Bicep paths for new and existing Azure AI resources.
- `setup.ps1`: guided Azure selection, fine-tuned-model quota preflight, deployment preview, OIDC and GitHub configuration.
- `LAB12_VALIDATION.md`: completed checks and the live-validation boundary.

The workflow is stored at repository root in `.github/workflows/fine-tune-medtriage.yml`, as required by GitHub Actions. Each learner creates a repository with **Use this template**, clones it, and runs `setup.ps1` once. Setup reuses existing Azure CLI and GitHub CLI sign-ins and configures repository-specific GitHub OIDC trust, Actions settings, and a Foundry project connection. The learner then changes only `hyperparameters.n_epochs` from 2 to 3 and pushes directly to the new repository's `main` branch. That push starts the workflow immediately; no pull request or instructor approval is required. Future experiments may replace reviewed data or change other configuration values.

After the job succeeds, the learner evaluates checkpoints, deploys an approved
fine-tuned checkpoint, opens it in the Foundry playground, applies the same
MedTriage system instruction used by the dataset, and compares unseen prompts
against `medtriage-base`. The learner then finds the deployment endpoint, name,
and API key in Foundry and tests the deployment with Python. Fine-tuning is
considered effective only when held-out JSON compliance, urgency labeling, and
safety behavior improve.
