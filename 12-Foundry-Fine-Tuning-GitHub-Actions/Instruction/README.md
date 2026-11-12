# Exercise 12: Automatic Foundry fine-tuning from GitHub

## Goal

Change one fine-tuning hyperparameter, push the change through GitHub, and watch GitHub Actions create and monitor a supervised fine-tuning job in Microsoft Foundry.

The instructor configures Azure, GitHub OIDC, quota, and the base-model deployment once. Students do **not** create Azure resources, service principals, secrets, or role assignments.

## Student workflow

```text
Fork the course repository
        ↓
Clone your fork
        ↓
Change n_epochs from 2 to 3
        ↓
Validate, commit, and push
        ↓
Open a pull request
        ↓
Instructor reviews and merges
        ↓
GitHub Actions creates and monitors the Foundry job
```

## Before you start

Install:

- Git
- Python 3.10 or later
- A code editor such as Visual Studio Code

You also need a GitHub account so you can create a fork and push your change. You do not need Azure CLI or GitHub CLI for the student steps.

## Step 1: Fork and clone the repository

1. Sign in to [GitHub](https://github.com/).
2. Open [kavsrd13/operationalize-ml-models-labs](https://github.com/kavsrd13/operationalize-ml-models-labs).
3. Select **Fork** and then **Create fork**.
4. Replace `YOUR-GITHUB-USERNAME` below and run:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git remote add upstream https://github.com/kavsrd13/operationalize-ml-models-labs.git
git switch -c exercise-12-three-epochs
```

Cloning the public course repository does not require a login. Git asks you to sign in only when you create the fork in the browser or push to your fork.

## Step 2: Change the number of epochs

Open:

`12-Foundry-Fine-Tuning-GitHub-Actions/config/finetune.json`

Find this section:

```json
"hyperparameters": {
  "n_epochs": 2,
  "batch_size": 4,
  "learning_rate_multiplier": 0.5
}
```

Change only `n_epochs` from `2` to `3`:

```json
"hyperparameters": {
  "n_epochs": 3,
  "batch_size": 4,
  "learning_rate_multiplier": 0.5
}
```

Do not change the model, training type, batch size, learning-rate multiplier, or seed in this exercise. Changing one value at a time makes the experiment easy to compare with the two-epoch reference run.

## Step 3: Validate the configuration

Run this command from the repository root:

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_config.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

The final line must report `n_epochs: 3`. Fix any error before pushing.

## Step 4: Commit and push the change

First confirm that Git shows only the intended change:

```powershell
git diff -- .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

Commit and push your branch:

```powershell
git add .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
git commit -m "Exercise 12: compare three training epochs"
git push -u origin exercise-12-three-epochs
```

Complete the Git Credential Manager browser sign-in if Git requests it.

## Step 5: Open a pull request

1. Open your fork on GitHub.
2. Select **Compare & pull request**.
3. Confirm the base repository is `kavsrd13/operationalize-ml-models-labs` and the base branch is `main`.
4. In the description, write: `Changed n_epochs from 2 to 3.`
5. Select **Create pull request**.

The workflow does not use Azure from your fork. The instructor first reviews the change and then merges it into the upstream `main` branch. That merge starts the paid experiment automatically.

## Step 6: Watch the automated experiment

After the instructor merges the pull request, open [GitHub Actions](https://github.com/kavsrd13/operationalize-ml-models-labs/actions) and select **Exercise 12 - Fine-tune MedTriage model**.

The run performs these steps:

1. Validates the configuration and the existing reviewed datasets.
2. Signs in to Azure through GitHub OIDC without a stored password.
3. Evaluates ten held-out examples against `medtriage-base`.
4. Uploads the training and validation files through the Azure AI Projects SDK.
5. Calls `fine_tuning.jobs.create()` with the supervised hyperparameters.
6. Displays the new Foundry job ID in the GitHub summary.
7. Monitors the job until it succeeds, fails, or is cancelled.
8. Records checkpoints and uploads the experiment evidence as a GitHub artifact.

The base-model evaluation usually takes a few minutes. Fine-tuning takes longer. Do not push another experiment while the current run is active.

## Step 7: Confirm the Foundry job

In Microsoft Foundry:

1. Open resource group `Krishna`.
2. Open the Azure AI Services resource `Finetunning121`.
3. Open project `proj-default`.
4. Open **Fine-tuning**.
5. Match the job ID with the GitHub Actions summary.
6. Confirm the base model is `gpt-4.1-mini-2025-04-14` and the job uses three epochs.

A created job proves that automation works. It does not prove that the model is better or safe to deploy.

## Step 8: Review and deploy only after approval

After the job succeeds, the instructor compares its checkpoints and held-out results with the recorded base-model metrics. If the result is approved:

1. Open the successful job in Foundry.
2. Select **Deploy** and then **Serverless**.
3. Use a name such as `medtriage-ft-v1`.
4. Choose **Global Standard**.
5. Test with prompts that were not used for training or validation.
6. Delete the serving deployment after the exercise to stop its hosting cost.

## Optional future experiments

The automation also starts when an instructor-approved pull request changes files under the Exercise 12 `data` or `config` folder. A later experiment may replace the reviewed training and validation files or change a different approved hyperparameter. This student exercise changes only `n_epochs`.

## Troubleshooting

- **Fork is unavailable:** Sign in to GitHub and confirm the instructor made the repository public.
- **Push is rejected:** Confirm `origin` points to your fork by running `git remote -v`.
- **No workflow runs in your fork:** This is expected. Forks cannot use the instructor's Azure configuration.
- **No upstream workflow appears:** Confirm the instructor merged the pull request into `main`.
- **Validation fails:** Correct the value or JSON syntax and push another commit to the same branch.
- **No Foundry job appears immediately:** Wait for the base-model evaluation and the **Upload data and submit supervised fine-tuning** step to finish.
- **Azure sign-in or configuration fails:** Notify the instructor. Students should not recreate secrets, identities, or Azure resources.
- **Quota error:** The instructor must check the selected model, region, training tier, and fine-tuned deployment quota before retrying.

## Instructor setup

Only the instructor runs:

```powershell
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1
```

The script selects or creates the Foundry resource and project, verifies quota, deploys the reusable `medtriage-base` model, creates GitHub OIDC trust, assigns Foundry User only at project scope, and configures the GitHub secrets and variables.

Before class, the instructor must:

1. Make the course repository public.
2. Complete `setup.ps1` once.
3. Confirm `medtriage-base` is healthy.
4. Confirm the workflow can create a test job.
5. Review every pull request before merging because a merge can start paid training.

The implementation follows the official [Azure AI Projects Python client](https://learn.microsoft.com/python/api/overview/azure/ai-projects-readme) and [Microsoft Foundry supervised fine-tuning](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/fine-tuning) patterns. See [LAB12_VALIDATION.md](../LAB12_VALIDATION.md) for the tested environment and live evidence.
