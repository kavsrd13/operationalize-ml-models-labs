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
- `tests/`: offline assertions for the exact SDK request shape.
- `infra/`: separate Bicep paths for new and existing Azure AI resources.
- `setup.ps1`: guided Azure selection, fine-tuned-model quota preflight, deployment preview, OIDC and GitHub configuration.
- `LAB12_VALIDATION.md`: completed checks and the live-validation boundary.

The workflow is stored at repository root in `.github/workflows/fine-tune-medtriage.yml`, as required by GitHub Actions. Infrastructure, the Foundry project and OIDC are configured once by the instructor. Students fork the public repository, edit data or configuration in their fork, and open a pull request. The Azure workflow is deliberately restricted to `kavsrd13/operationalize-ml-models-labs`; it starts only after an instructor reviews and merges the pull request into upstream `main`.
