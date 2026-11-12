# Exercise 12: Foundry fine-tuning with GitHub Actions

This standalone exercise validates a versioned MedTriage supervised fine-tuning dataset, establishes passwordless GitHub-to-Azure authentication with OIDC, measures a `gpt-4.1-mini` baseline, and submits a Microsoft Foundry fine-tuning job.

Open [Instruction/README.md](Instruction/README.md) for the editable student guide or [Instruction/index.html](Instruction/index.html) for the generated offline page.

## Folder map

- `data/`: 255 training and 45 validation JSONL records.
- `config/finetune.json`: versioned model and hyperparameter choices.
- `scripts/validate_dataset.py`: free structural and label validation.
- `scripts/validate_config.py`: blocks unsupported model or training choices before Azure access.
- `scripts/evaluate_baseline.py`: held-out base-model baseline.
- `scripts/submit_finetune.py`: authenticated upload and job submission.
- `infra/`: separate Bicep paths for new and existing Azure AI resources.
- `setup.ps1`: guided Azure selection, fine-tuned-model quota preflight, deployment preview, OIDC and GitHub configuration.
- `LAB12_VALIDATION.md`: completed checks and the live-validation boundary.

The workflow is stored at repository root in `.github/workflows/fine-tune-medtriage.yml`, as required by GitHub Actions. Infrastructure and OIDC are configured once by the instructor. Students replace the two versioned JSONL files, edit `config/finetune.json`, and push to `main`; validation, baseline evaluation and fine-tuning submission then run automatically.
