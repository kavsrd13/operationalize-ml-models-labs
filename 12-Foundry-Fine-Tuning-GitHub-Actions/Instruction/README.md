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
      ↓
Monitor and evaluate the new model
      ↓
Deploy the approved model with Global Standard
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

Add or replace one training JSONL file and one validation JSONL file anywhere under:

`12-Foundry-Fine-Tuning-GitHub-Actions/data/`

The workflow does not contain fixed dataset filenames. It automatically finds exactly one `.jsonl` filename containing `training` and exactly one containing `validation`. For example, both `medical_triage_training.jsonl` and `my_training_v2.jsonl` are valid. If you intentionally keep more than one training or validation file, add `training_file` and `validation_file` to `config/finetune.json` to select them explicitly.

Each JSONL line must contain exactly three messages in this order:

```json
{"messages":[{"role":"system","content":"..."},{"role":"user","content":"..."},{"role":"assistant","content":"{\"urgency\":\"Routine\",\"department\":\"Primary Care\",\"reason\":\"...\",\"next_step\":\"...\"}"}]}
```

The assistant content must be a JSON string containing exactly `urgency`, `department`, `reason`, and `next_step`. This medical demonstration must contain no personal health information. A qualified reviewer must approve its labels and emergency wording before the push because the push starts a paid job automatically.

Optional local check:

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_dataset.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_training.jsonl `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_validation.jsonl
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

Dataset paths are optional because automatic discovery is the default. When the `data` folder contains multiple candidate files, add these entries before the `model` entry, using paths relative to the Exercise 12 folder:

```json
"training_file": "data/my_training_v2.jsonl",
"validation_file": "data/my_validation_v2.jsonl",
```

> Important: the earlier completed `gpt-4o-mini-2024-07-18` job cannot be changed into a `gpt-4.1-mini` model. Its fine-tuned deployment quota is zero in the teaching subscription. You must submit a new job with the configuration above. The workflow now rejects any other model before uploading data or starting paid training.

## 4. Push and start fine-tuning automatically

Stage the changed files under the data and config folders:

```powershell
git add -- `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\ `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\

git commit -m "Exercise 12: submit fine-tuning experiment"
git push origin main
```

That push is the trigger. Any committed change under `data/**` or `config/**` starts the workflow. The workflow itself contains no hardcoded dataset filename. Do not run another setup command and do not manually start the workflow.

## 5. Watch the automatic workflow

```powershell
gh run list `
  --workflow fine-tune-medtriage.yml `
  --repo kavsrd13/operationalize-ml-models-labs

gh repo view kavsrd13/operationalize-ml-models-labs --web
```

Open **Actions → Exercise 12 - Fine-tune MedTriage model**. The workflow performs these steps:

1. Confirms the configuration uses `gpt-4.1-mini-2025-04-14` with `globalStandard` training.
2. Discovers the training and validation files, or reads their optional paths from the configuration.
3. Validates every JSONL line and checks that training and validation questions do not overlap.
4. Uses GitHub OIDC to obtain a short-lived Azure token. No Azure password or API key is stored.
5. Evaluates ten held-out examples against the `medtriage-base` deployment.
6. Uploads the discovered training and validation files.
7. Submits one supervised fine-tuning job using the committed configuration.
8. Saves `baseline_metrics.json` and `fine_tuning_job.json` as a GitHub artifact.

The GitHub summary records the commit and Foundry job ID. A green GitHub run means submission succeeded; Foundry training continues asynchronously.

## 6. Monitor the Foundry job

Open the Azure AI Services resource `Finetunning121` in resource group `Krishna`, then open its fine-tuning jobs. Match the job ID with the GitHub summary and monitor it to a terminal status.

Confirm the job's base model is `gpt-4.1-mini-2025-04-14`. Do not deploy it merely because training completed. Compare it with the recorded baseline, inspect checkpoints and safety behavior, and require instructor approval before deployment.

## 7. Deploy the approved fine-tuned model

After the instructor approves the evaluation:

1. Open the completed `gpt-4.1-mini` fine-tuning job in Microsoft Foundry.
2. Select **Deploy**, then select **Serverless**.
3. Enter a deployment name such as `medtriage-ft-v1`.
4. Select **Global Standard**. Do not select the old `gpt-4o-mini` model and do not use **Data Zone Standard** for this lab.
5. Start with the smallest capacity offered by the portal, confirm it is within the displayed quota, and create the deployment.
6. Wait for provisioning to finish, select the fine-tuned deployment in the playground, and test it with held-out prompts that were not in either JSONL file.
7. Record the deployment name and evaluation result, then delete the serving deployment after the lab to stop its hourly hosting charge.

The live check on 12 November 2026 found 500K TPM of East US Global Standard fine-tuned quota for `gpt-4.1-mini`. Quota is subscription-specific, so students must use the instructor-configured subscription and resource. Microsoft Foundry also supports cross-region and cross-subscription deployment when the destination supports fine-tuning and the deploying identity can access both resources, but this lab intentionally stays on `Krishna/Finetunning121`.

## Files students edit

| File | Student action |
|---|---|
| `data/*.jsonl` | Add one reviewed training file and one held-out validation file; filenames may change |
| `config/finetune.json` | Set the experiment suffix and approved hyperparameters; optionally select dataset paths |

All Bicep, OIDC and setup files are instructor-maintained. The GitHub workflow is also instructor-maintained.

## Troubleshooting

- Push rejected: confirm the instructor granted write access and that you are on `main`.
- Workflow does not appear: confirm the pushed commit changed something under `data/**` or `config/**`.
- Dataset discovery fails: keep exactly one filename containing `training` and one containing `validation`, or specify both paths in `finetune.json`.
- Validation fails: open the failed step; fix the reported JSONL line, output schema, urgency label or train/validation overlap, then push a correction.
- Azure login fails: notify the instructor; students should not recreate secrets or identities.
- Fine-tuning submission reports quota or model availability: notify the instructor before retrying to avoid duplicate jobs.
- Deployment says insufficient quota: verify the completed job is based on `gpt-4.1-mini`, choose **Global Standard**, and confirm you are using the instructor's East US resource. The old `gpt-4o-mini` result has zero fine-tuned deployment quota in this subscription.
- GitHub is green while Foundry is still running: expected—the workflow submits the asynchronous training job but does not wait for completion.

## One-time instructor setup

Only an instructor or repository administrator runs `12-Foundry-Fine-Tuning-GitHub-Actions/setup.ps1`. It creates or selects the Azure AI resource, verifies that the selected subscription and region have Global Standard fine-tuned `gpt-4.1-mini` quota, deploys version `2025-04-14` as `medtriage-base`, creates the managed identity and GitHub OIDC trust, assigns the scoped Azure role, and configures repository secrets and resource variables.

The current repository is configured for `origin/main`, resource group `Krishna`, Azure AI resource `Finetunning121`, and East US. Run setup again only if those instructor-managed resources change.

## Validation status

The dataset validator, pinned-model configuration validator, Python syntax, workflow YAML, PowerShell setup and both Bicep paths passed. On 12 November 2026, the Azure `what-if` accepted `gpt-4.1-mini` in East US. The selected subscription reported 5,000K TPM of Global Standard base quota and 500K TPM of Global Standard fine-tuned deployment quota for that model. The existing resource and `medtriage-base` deployment were provisioned and GitHub OIDC secrets were configured. The earlier successful `gpt-4o-mini` fine-tuning job remains undeployed because its Global Standard and Data Zone Standard fine-tuned quota is zero; a new paid `gpt-4.1-mini` job must be submitted through the push flow.
