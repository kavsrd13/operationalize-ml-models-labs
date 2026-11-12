# Exercise 12: Automatic Foundry fine-tuning from your GitHub fork

## Goal

Fork the course repository, connect your fork to your Microsoft Foundry project once, change `n_epochs` from 2 to 3, and push to `main`. Your push automatically starts a supervised fine-tuning job. No pull request or instructor approval is required.

## Student workflow

```text
Fork and clone the course repository
        ↓
Run setup.ps1 once for your fork and Azure account
        ↓
Change n_epochs from 2 to 3
        ↓
Validate, commit, and push to your fork's main branch
        ↓
GitHub Actions automatically creates and monitors the Foundry job
```

## Before you start

You need:

- A GitHub account.
- An Azure account with an enabled subscription.
- Permission to create or reuse a Foundry resource, create a managed identity, assign the **Foundry User** role, and create a model deployment. **Owner** on the exercise subscription is the simplest classroom option.
- Available `gpt-4.1-mini` fine-tuning quota in the selected Azure region.
- Git, Python 3.10 or later, PowerShell, [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), and [GitHub CLI](https://cli.github.com/).

Fine-tuning is billable. Use an exercise subscription and delete resources when the class is complete.

## Step 1: Fork and clone the repository

1. Sign in to [GitHub](https://github.com/).
2. Open [kavsrd13/operationalize-ml-models-labs](https://github.com/kavsrd13/operationalize-ml-models-labs).
3. Select **Fork**, and then select **Create fork**.
4. Replace `YOUR-GITHUB-USERNAME` and run:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git branch --show-current
```

The final command must show `main`. The `origin` remote now points to your fork, so the setup script configures your repository rather than the instructor's repository.

## Step 2: Sign in and configure your fork once

Sign in from the repository root:

```powershell
az login --use-device-code
gh auth login
```

For `gh auth login`, select:

1. `GitHub.com`
2. `HTTPS`
3. `Login with a web browser`

Run the guided setup:

```powershell
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1
```

The script detects your fork automatically. Follow the numbered choices shown in the terminal:

1. Select the Azure subscription by entering its displayed number.
2. Enter `1` to reuse an existing Foundry resource, `2` to create a new resource, or `3` to exit.
3. If you select an existing resource, enter the displayed resource and project numbers.
4. Review the Bicep preview. Enter `1` to deploy, `2` to display the preview again, or `3` to exit.

Setup performs the one-time platform work:

- Selects or creates the Foundry resource and project.
- Checks fine-tuning quota.
- Reuses or creates the `medtriage-base` deployment.
- Creates an identity trusted only by your fork's `main` branch.
- Assigns **Foundry User** only at the Foundry project scope.
- Enables GitHub Actions and the Exercise 12 workflow in your fork.
- Adds the required secrets and variables to your fork.

Continue only after the terminal reports `Automation is ready` and displays the Actions URL for your fork.

## Step 3: Change the number of epochs

Open:

`12-Foundry-Fine-Tuning-GitHub-Actions/config/finetune.json`

Find:

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

Keeping all other values unchanged makes the three-epoch experiment comparable with the two-epoch reference run.

## Step 4: Validate the change

Run from the repository root:

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_config.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

The final line must report `n_epochs: 3`.

Confirm that only the intended configuration changed:

```powershell
git diff -- .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
```

## Step 5: Push and trigger fine-tuning

Commit directly to your fork's `main` branch:

```powershell
git add .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
git commit -m "Exercise 12: compare three training epochs"
git push origin main
```

That push automatically triggers the workflow because a file under the Exercise 12 `config` folder changed. You do not open a pull request, and no instructor merge or approval is required.

## Step 6: Watch the automated experiment

1. Open your fork on GitHub.
2. Select **Actions**.
3. Select **Exercise 12 - Fine-tune MedTriage model**.
4. Open the run created by your push.

The workflow:

1. Validates the configuration and datasets.
2. Signs in to Azure through repository-specific GitHub OIDC without a client secret.
3. Evaluates ten held-out examples against `medtriage-base`.
4. Uploads the training and validation files through the Azure AI Projects SDK.
5. Calls `fine_tuning.jobs.create()` with the supervised hyperparameters.
6. Writes the Foundry job ID to the workflow summary.
7. Monitors the job until it succeeds, fails, or is cancelled.
8. Uploads the baseline and fine-tuning evidence as a GitHub artifact.

The baseline takes several minutes and fine-tuning takes longer. Do not push another data or configuration experiment while this run is active.

## Step 7: Confirm the Foundry job

Use the resource, project, and Actions URL printed by your setup script:

1. Open your Foundry project.
2. Open **Fine-tuning**.
3. Match the job ID to the ID in the GitHub Actions summary.
4. Confirm the base model is `gpt-4.1-mini-2025-04-14`.
5. Confirm the job uses three epochs.

A created job proves that the automation works. It does not prove that the fine-tuned model is better or safe to deploy.

## Step 8: Evaluate before deployment

After training succeeds, compare its checkpoints and held-out results with the base-model metrics stored in the GitHub artifact. Deploy only if the result improves the intended behavior without introducing unsafe or incorrect responses.

If you deploy for testing:

1. Open the successful fine-tuning job in Foundry.
2. Select **Deploy** and then **Serverless**.
3. Use a name such as `medtriage-ft-v1`.
4. Select **Global Standard** if quota is available.
5. Test with prompts that were not used for training or validation.
6. Delete the serving deployment after the exercise to stop its hosting cost.

## Optional future experiments

Any later push to your fork's `main` branch that changes Exercise 12 `data/**` or `config/**` starts another billable run. You may later replace the reviewed datasets or change a different supported hyperparameter. This exercise changes only `n_epochs`.

## Troubleshooting

- **Fork is unavailable:** Sign in to GitHub and confirm the source repository allows forks.
- **Setup reports that you are not an administrator:** Confirm `origin` points to your own fork with `git remote -v`.
- **Setup requires `main`:** Run `git switch main`, and then rerun setup.
- **No workflow run appears:** Confirm you pushed the configuration change to your fork's `main` branch. Rerun `setup.ps1` to enable Actions and the Exercise 12 workflow in the fork.
- **Azure configuration is missing:** Run `setup.ps1` from your fork and complete the deployment before pushing again.
- **OIDC sign-in fails:** Rerun `setup.ps1` from the same fork. OIDC trust is repository-specific and does not transfer from the source repository.
- **No Foundry job appears immediately:** Wait for the baseline step and the **Upload data and submit supervised fine-tuning** step to finish.
- **Quota error:** Select a subscription or region with available `gpt-4.1-mini` fine-tuning quota.
- **Push starts another paid run:** This is expected whenever Exercise 12 data or configuration changes on `main`. Wait for the active run before pushing another experiment.

The implementation follows the official [Azure AI Projects Python client](https://learn.microsoft.com/python/api/overview/azure/ai-projects-readme) and [Microsoft Foundry supervised fine-tuning](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/fine-tuning) patterns. See [LAB12_VALIDATION.md](../LAB12_VALIDATION.md) for tested evidence and the live-validation boundary.
