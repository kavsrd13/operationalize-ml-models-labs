# Exercise 12: Automatic Foundry fine-tuning from GitHub

## Outcome

Fork the public course repository, change one hyperparameter in your own GitHub repository, and open a pull request. After instructor review and merge, the upstream GitHub workflow validates the data, measures the base model, signs in to Azure without a password, uploads the files, submits a Microsoft Foundry supervised fine-tuning job through the Azure AI Projects SDK, and monitors it to completion.

The instructor has already completed the one-time Azure infrastructure and GitHub OIDC setup. Students do **not** run `setup.ps1`, create a service principal, create Azure resources, or configure GitHub secrets.

## The complete student workflow

```text
Open public repository (anonymous read-only access)
      ↓
Sign in to GitHub and fork it
      ↓
Clone your fork and create a branch
      ↓
Change hyperparameters.n_epochs from 2 to 3
      ↓
Push to your fork and open a pull request
      ↓
Instructor reviews and merges into upstream main
      ↓
Upstream GitHub validates → evaluates baseline → fine-tunes
      ↓
Monitor and evaluate the new model
      ↓
Deploy the approved model with Global Standard
```

## 1. Fork and clone the public repository

Anyone can inspect or clone the public course repository without signing in:

```powershell
git clone https://github.com/kavsrd13/operationalize-ml-models-labs.git
```

To complete and submit the exercise, you need your own fork:

1. Sign in to [GitHub](https://github.com/).
2. Open [kavsrd13/operationalize-ml-models-labs](https://github.com/kavsrd13/operationalize-ml-models-labs).
3. Select **Fork**.
4. Keep the repository name `operationalize-ml-models-labs` and select **Create fork**.
5. Clone your fork by replacing `YOUR-GITHUB-USERNAME` below:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git remote add upstream https://github.com/kavsrd13/operationalize-ml-models-labs.git
git remote -v
git switch -c exercise-12-three-epochs
```

No `gh auth login` command is required. Public cloning is anonymous. GitHub sign-in is required only to create the fork, push to your fork, and open the pull request. Students do not create a service principal, Azure resource, GitHub secret or OIDC configuration.

## 2. Add your reviewed data

Add or replace one training JSONL file and one validation JSONL file anywhere under:

`12-Foundry-Fine-Tuning-GitHub-Actions/data/`

The workflow does not contain fixed dataset filenames. It automatically finds exactly one `.jsonl` filename containing `training` and exactly one containing `validation`. For example, both `medical_triage_training.jsonl` and `my_training_v2.jsonl` are valid. If you intentionally keep more than one training or validation file, add `training_file` and `validation_file` to `config/finetune.json` to select them explicitly.

Each JSONL line must contain exactly three messages in this order:

```json
{"messages":[{"role":"system","content":"..."},{"role":"user","content":"..."},{"role":"assistant","content":"{\"urgency\":\"Routine\",\"department\":\"Primary Care\",\"reason\":\"...\",\"next_step\":\"...\"}"}]}
```

The assistant content must be a JSON string containing exactly `urgency`, `department`, `reason`, and `next_step`. This medical demonstration must contain no personal health information. A qualified reviewer must approve its labels and emergency wording before the pull request is merged because the upstream merge starts a paid job automatically.

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
  "method": "supervised",
  "training_type": "GlobalStandard",
  "hyperparameters": {
    "n_epochs": 2,
    "batch_size": 4,
    "learning_rate_multiplier": 0.5
  },
  "seed": 42,
  "suffix": "medtriage-json"
}
```

The fields have different engineering responsibilities:

| Field | Purpose |
|---|---|
| `model` | Exact trainable base-model version |
| `method` | Supervised fine-tuning (SFT), because the dataset contains input/output demonstrations |
| `training_type` | Foundry compute and data placement; it is **not** a model hyperparameter |
| `hyperparameters.n_epochs` | Number of complete passes through the training set |
| `hyperparameters.batch_size` | Examples used in each gradient update |
| `hyperparameters.learning_rate_multiplier` | Scales how aggressively the model weights change |
| `seed` | Improves repeatability between experiments |
| `suffix` | Names the resulting model; it does not affect learning |

The committed configuration is the two-epoch reference. In this exercise, change exactly one learning control: set `hyperparameters.n_epochs` from `2` to `3`. Keep `batch_size` at `4`, `learning_rate_multiplier` at `0.5`, and `seed` at `42`. This one-variable-at-a-time design lets you attribute any change in training loss, validation loss or held-out behavior to the additional epoch.

Your edited section must look like this:

```json
"hyperparameters": {
  "n_epochs": 3,
  "batch_size": 4,
  "learning_rate_multiplier": 0.5
}
```

Validate the edited configuration before committing:

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_config.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

The successful message must report `n_epochs: 3`. Do not push if validation fails.

Dataset paths are optional because automatic discovery is the default. When the `data` folder contains multiple candidate files, add these entries before the `model` entry, using paths relative to the Exercise 12 folder:

```json
"training_file": "data/my_training_v2.jsonl",
"validation_file": "data/my_validation_v2.jsonl",
```

> Important: the earlier completed `gpt-4o-mini-2024-07-18` job cannot be changed into a `gpt-4.1-mini` model. Its fine-tuned deployment quota is zero in the teaching subscription. You must submit a new job with the configuration above. The workflow now rejects any other model before uploading data or starting paid training.

## 4. Push to your fork and open a pull request

First confirm that Git shows the intended `2` to `3` change:

```powershell
git diff -- .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

Then stage the changed files, commit, and push your exercise branch to your fork:

```powershell
git add -- `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\ `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\

git commit -m "Exercise 12: train three-epoch experiment"
git push -u origin exercise-12-three-epochs
```

When Git asks you to authenticate for the push, complete the browser sign-in shown by Git Credential Manager. This is push authentication, not a prerequisite for public cloning.

After the push:

1. Open your fork on GitHub.
2. Select **Compare & pull request**.
3. Confirm the base repository is `kavsrd13/operationalize-ml-models-labs`, the base branch is `main`, and the head branch is your `exercise-12-three-epochs` branch.
4. Explain that you changed only `n_epochs` from two to three.
5. Select **Create pull request**.

The push to your fork does **not** receive or use the instructor's Azure settings. Fine-tuning starts only after the instructor reviews the data and configuration and merges the pull request into the upstream `main` branch. This prevents unreviewed fork code from accessing Azure.

## 5. Watch the upstream workflow after merge

Open [upstream GitHub Actions](https://github.com/kavsrd13/operationalize-ml-models-labs/actions), then select **Exercise 12 - Fine-tune MedTriage model**. The workflow appears after the instructor merges the pull request and performs these steps:

1. Confirms the configuration uses `gpt-4.1-mini-2025-04-14`, supervised training and `GlobalStandard` placement.
2. Discovers the training and validation files, or reads their optional paths from the configuration.
3. Validates every JSONL line and checks that training and validation questions do not overlap.
4. Uses GitHub OIDC and `DefaultAzureCredential`; no Azure password, client secret or API key is stored.
5. Creates `AIProjectClient` with the configured Microsoft Foundry project endpoint.
6. Evaluates ten held-out examples against the `medtriage-base` deployment.
7. Uploads the discovered training and validation files with `openai_client.files.create()` and waits for processing.
8. Calls `openai_client.fine_tuning.jobs.create()` with SFT hyperparameters under `method.supervised.hyperparameters`.
9. Monitors the job to `succeeded`, `failed` or `cancelled`, and collects checkpoint metadata after success.
10. Saves `baseline_metrics.json`, `fine_tuning_job.json` and `fine_tuning_result.json` as a GitHub artifact.

The GitHub summary records the commit, job ID, baseline and final fine-tuned model ID. A green GitHub run now means the Foundry job reached `succeeded`, not merely that it was submitted.

The implementation follows the official [Azure AI Projects client library](https://learn.microsoft.com/python/api/overview/azure/ai-projects-readme) and [Microsoft Foundry supervised fine-tuning](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/fine-tuning) patterns.

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

- Anonymous clone fails: confirm you used the public HTTPS URL and that the instructor has made the repository public.
- Fork option is unavailable: sign in to GitHub in the browser; forking requires a GitHub account even though cloning a public repository does not.
- Push rejected: confirm `origin` points to your fork and complete the Git Credential Manager browser sign-in.
- Workflow does not run in your fork: expected. Fork workflows are blocked from the instructor's Azure environment.
- Upstream workflow does not appear: confirm the instructor merged the pull request and that the merged change is inside the `data` or `config` folder.
- Dataset discovery fails: keep exactly one filename containing `training` and one containing `validation`, or specify both paths in `finetune.json`.
- Validation fails: open the failed step; fix the reported JSONL line, output schema, urgency label or train/validation overlap, then push a correction.
- Azure login fails: notify the instructor; students should not recreate secrets or identities.
- Fine-tuning submission reports quota or model availability: notify the instructor before retrying to avoid duplicate jobs.
- Deployment says insufficient quota: verify the completed job is based on `gpt-4.1-mini`, choose **Global Standard**, and confirm you are using the instructor's East US resource. The old `gpt-4o-mini` result has zero fine-tuned deployment quota in this subscription.
- Workflow runs for a long time: expected—the monitor polls Foundry until training reaches a terminal state. Do not push another experiment while it is running.

## One-time instructor setup

Only an instructor or repository administrator runs `12-Foundry-Fine-Tuning-GitHub-Actions/setup.ps1`. It creates or selects the Microsoft Foundry resource and project, verifies that the selected subscription and region have Global Standard fine-tuned `gpt-4.1-mini` quota, deploys version `2025-04-14` as `medtriage-base`, creates the managed identity and GitHub OIDC trust, assigns the scoped Azure role, and configures the project endpoint and other repository settings.

Before sharing the exercise, the instructor must set the repository visibility to **Public**. The Azure workflow contains a canonical-repository guard and cannot run against Azure from student forks. GitHub Actions secrets and variables are not inherited by forks.

The current repository is configured for `origin/main`, resource group `Krishna`, Microsoft Foundry resource `Finetunning121`, project `proj-default`, and East US. Run setup again only if those instructor-managed resources change.

## Validation status

The dataset validator, pinned-model configuration validator, Python syntax, workflow YAML, PowerShell setup and both Bicep paths passed. On 12 November 2026, the Azure `what-if` accepted `gpt-4.1-mini` in East US. The selected subscription reported 5,000K TPM of Global Standard base quota and 500K TPM of Global Standard fine-tuned deployment quota for that model. The existing resource and `medtriage-base` deployment were provisioned and GitHub OIDC secrets were configured. The earlier successful `gpt-4o-mini` fine-tuning job remains undeployed because its Global Standard and Data Zone Standard fine-tuned quota is zero; a new paid `gpt-4.1-mini` job must be submitted through the push flow.
