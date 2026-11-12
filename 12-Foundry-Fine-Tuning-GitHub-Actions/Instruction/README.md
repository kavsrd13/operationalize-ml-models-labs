# Exercise 12: Automatic Foundry fine-tuning from GitHub

## Outcome

Replace the training data, edit one configuration file, and push to `main`. GitHub automatically validates the data, measures the base model, signs in to Azure without a password, uploads the files, and submits a Microsoft Foundry supervised fine-tuning job.

The instructor has already completed the one-time Azure infrastructure and GitHub OIDC setup. Students do **not** run `setup.ps1`, create a service principal, create Azure resources, or configure GitHub secrets.

## The complete student workflow

```text
Clone repository
      ↓
Replace training and validation JSONL files
      ↓
Edit config/finetune.json
      ↓
Commit and push to origin/main
      ↓
GitHub validates → evaluates baseline → submits fine-tuning
```

## 1. Clone the repository

Ask the instructor for write access to `kavsrd13/operationalize-ml-models-labs`. Install Git and GitHub CLI, then run:

```powershell
gh auth login
gh repo clone kavsrd13/operationalize-ml-models-labs
Set-Location .\operationalize-ml-models-labs
git switch main
git pull --ff-only origin main
```

The exercise uses the shared course repository and its `main` branch. Do not create another repository, remote, service principal or Azure resource.

## 2. Add your reviewed data

Replace the contents of these two existing files without changing their filenames:

- `12-Foundry-Fine-Tuning-GitHub-Actions/data/medical_triage_training_300.jsonl`
- `12-Foundry-Fine-Tuning-GitHub-Actions/data/medical_triage_validation_300.jsonl`

Each JSONL line must contain exactly three messages in this order:

```json
{"messages":[{"role":"system","content":"..."},{"role":"user","content":"..."},{"role":"assistant","content":"{\"urgency\":\"Routine\",\"department\":\"Primary Care\",\"reason\":\"...\",\"next_step\":\"...\"}"}]}
```

The assistant content must be a JSON string containing exactly `urgency`, `department`, `reason`, and `next_step`. This medical demonstration must contain no personal health information. A qualified reviewer must approve its labels and emergency wording before the push because the push starts a paid job automatically.

Optional local check:

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_dataset.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_training_300.jsonl `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_validation_300.jsonl
```

The included example currently reports 255 training records, 45 validation records, one system prompt and zero identical questions across the splits.

## 3. Edit the fine-tuning configuration

Open `12-Foundry-Fine-Tuning-GitHub-Actions/config/finetune.json`:

```json
{
  "model": "gpt-4.1-mini-2025-04-14",
  "training_type": "globalStandard",
  "n_epochs": 2,
  "learning_rate_multiplier": 1.0,
  "suffix": "medtriage-json"
}
```

For the first run, keep the model and training type unchanged. Give `suffix` a short experiment name. Change epochs or learning rate only when the experiment has a clear comparison objective.

## 4. Push and start fine-tuning automatically

Stage only the two data files and configuration:

```powershell
git add `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_training_300.jsonl `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_validation_300.jsonl `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json

git commit -m "Exercise 12: submit fine-tuning experiment"
git push origin main
```

That push is the trigger. Do not run another setup command and do not manually start the workflow.

## 5. Watch the automatic workflow

```powershell
gh run list `
  --workflow fine-tune-medtriage.yml `
  --repo kavsrd13/operationalize-ml-models-labs

gh repo view kavsrd13/operationalize-ml-models-labs --web
```

Open **Actions → Exercise 12 - Fine-tune MedTriage model**. The workflow performs these steps:

1. Validates every JSONL line and checks that training and validation questions do not overlap.
2. Uses GitHub OIDC to obtain a short-lived Azure token. No Azure password or API key is stored.
3. Evaluates ten held-out examples against the `medtriage-base` deployment.
4. Uploads the training and validation files.
5. Submits one supervised fine-tuning job using the committed configuration.
6. Saves `baseline_metrics.json` and `fine_tuning_job.json` as a GitHub artifact.

The GitHub summary records the commit and Foundry job ID. A green GitHub run means submission succeeded; Foundry training continues asynchronously.

## 6. Monitor the Foundry job

Open the Azure AI Services resource `Finetunning121` in resource group `Krishna`, then open its fine-tuning jobs. Match the job ID with the GitHub summary and monitor it to a terminal status.

Do not deploy the resulting model merely because training completed. Compare it with the recorded baseline, inspect checkpoints and safety behavior, confirm deployment quota, and require instructor approval before deployment.

## Files students edit

| File | Student action |
|---|---|
| `data/medical_triage_training_300.jsonl` | Replace with reviewed training examples |
| `data/medical_triage_validation_300.jsonl` | Replace with held-out validation examples |
| `config/finetune.json` | Set the experiment suffix and approved hyperparameters |

All Bicep, OIDC and setup files are instructor-maintained. The GitHub workflow is also instructor-maintained.

## Troubleshooting

- Push rejected: confirm the instructor granted write access and that you are on `main`.
- Workflow does not appear: confirm one of the two data files or `config/finetune.json` changed in the pushed commit.
- Validation fails: open the failed step; fix the reported JSONL line, output schema, urgency label or train/validation overlap, then push a correction.
- Azure login fails: notify the instructor; students should not recreate secrets or identities.
- Fine-tuning submission reports quota or model availability: notify the instructor before retrying to avoid duplicate jobs.
- GitHub is green while Foundry is still running: expected—the workflow submits the asynchronous training job but does not wait for completion.

## One-time instructor setup

Only an instructor or repository administrator runs `12-Foundry-Fine-Tuning-GitHub-Actions/setup.ps1`. It creates or selects the Azure AI resource, deploys `gpt-4.1-mini` version `2025-04-14` as `medtriage-base`, creates the managed identity and GitHub OIDC trust, assigns the scoped Azure role, and configures repository secrets and resource variables.

The current repository is configured for `origin/main`, resource group `Krishna`, Azure AI resource `Finetunning121`, and East US. Run setup again only if those instructor-managed resources change.

## Validation status

The dataset validator, Python syntax, workflow YAML, PowerShell setup and both Bicep paths passed. On 12 November 2026, the Azure `what-if` accepted the current base model in East US, and the selected subscription reported base and fine-tuning quota. The existing resource and `medtriage-base` deployment were subsequently provisioned and GitHub OIDC secrets were configured. A new paid fine-tuning job has not yet been submitted through this simplified push flow.
