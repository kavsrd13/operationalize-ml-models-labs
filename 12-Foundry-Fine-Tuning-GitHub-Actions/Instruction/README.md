# Exercise 12: Automatic Foundry fine-tuning from your GitHub repository

## Goal

Create your own repository from the course template, connect it to your Microsoft Foundry project once, change `n_epochs` from 2 to 3, and push to `main`. Your push automatically starts a supervised fine-tuning job. No pull request or instructor approval is required.

## Why fine-tune this model?

The base `gpt-4.1-mini` model can already understand symptom descriptions, but
this exercise requires a repeatable task-specific behavior:

- Return one JSON object with exactly `urgency`, `department`, `reason`, and
  `next_step`.
- Use only the four approved urgency labels.
- Route requests to an appropriate department.
- Refuse diagnosis and medication-dose requests.
- Treat non-triage requests as `Not Applicable`.

Supervised fine-tuning shows the model many reviewed input-output examples and
updates its weights toward that behavior. This can improve format consistency,
label consistency, and response style without putting many examples into every
production prompt. Fine-tuning is effective only when the examples are accurate,
consistent, representative, and measured against a base-model baseline and a
held-out test set.

Fine-tuning does **not** add a trusted medical knowledge source, guarantee a
correct triage decision, or replace prompt safety rules, clinical review, and
formal evaluation. This is a training demonstration and must not be used for
real patient care.

## Student workflow

```text
Create your repository from the template and clone it
        ↓
Check your Azure and GitHub CLI sign-ins; run setup.ps1 once
        ↓
Change n_epochs from 2 to 3
        ↓
Validate, commit, and push to your repository's main branch
        ↓
GitHub Actions automatically creates and monitors the Foundry job
        ↓
Deploy an evaluated checkpoint
        ↓
Test the fine-tuned deployment in the Foundry playground
```

## Before you start

You need:

- A GitHub account.
- An Azure account with an enabled subscription.
- Permission to create or reuse a Foundry resource, create a managed identity, assign the **Foundry User** role, and create a model deployment. **Owner** on the exercise subscription is the simplest classroom option.
- Available `gpt-4.1-mini` fine-tuning quota in the selected Azure region.
- Git, Python 3.10 or later, PowerShell, [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), and [GitHub CLI](https://cli.github.com/).

Fine-tuning is billable. Use an exercise subscription and delete resources when the class is complete.

## Step 1: Create your GitHub copy and clone it

1. Open [kavsrd13/operationalize-ml-models-labs](https://github.com/kavsrd13/operationalize-ml-models-labs).
2. Select **Use this template** → **Create a new repository**. Choose your
   GitHub account and give the repository any name, such as `mlops3`.
3. Clone your GitHub copy. Replace both names below with your GitHub account
   and repository name. Git creates a local folder with the repository name:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/YOUR-REPOSITORY-NAME.git
Set-Location .\YOUR-REPOSITORY-NAME
git switch main
```

For example, if your repository is `kavsrd13/mlops3`, run:

```powershell
git clone https://github.com/kavsrd13/mlops3.git
Set-Location .\mlops3
git switch main
```

4. Confirm that you are in your new clone and `origin` points to your GitHub
   copy:

```powershell
Get-Location
git status --short
git remote get-url origin
```

`git status --short` must print nothing. Setup detects your repository from
`origin`; it never asks you to type an owner/repository value.

## Step 2: Check your Azure and GitHub sign-ins

If you are already signed in to Azure CLI and GitHub CLI on this computer,
skip the login commands. Otherwise, from the repository root, run each one
that you still need:

```powershell
az login
gh auth login
```

For GitHub CLI, select **GitHub.com**, **HTTPS**, and browser authentication.
Authorize the account that owns your student repository.

Check both sessions without signing in again:

```powershell
az account show --output table
gh auth status
```

Setup checks these sessions again and reuses them. Later, GitHub Actions uses
repository-specific OIDC to obtain its own short-lived Azure token; it does
not reuse your local Azure CLI sign-in.

## Step 3: Run the guided setup

Stay at the repository root and run:

```powershell
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1
```

The script detects your repository from `origin` and stops if you are in the
course source repository or a branch other than `main`. Follow the numbered
choices shown in the terminal:

1. Select the Azure subscription by entering its displayed number.
2. Enter `1` to reuse an existing Foundry resource, `2` to create a new resource, or `3` to exit.
3. If you select an existing resource, enter its displayed number. If more than
   one project exists, enter the displayed project number too.
4. Review the Bicep preview. Enter `1` to deploy, `2` to display the preview again, or `3` to exit.

Setup performs the one-time platform work:

- Selects or creates the Foundry resource and project.
- Checks fine-tuning quota.
- Reuses or creates the `medtriage-base` deployment.
- Creates an identity trusted only by your repository's `main` branch.
- Assigns **Foundry User** only at the Foundry project scope.
- Enables GitHub Actions and the Exercise 12 workflow in your repository.
- Adds the required secrets and variables to your repository.

Continue only after the terminal reports `Automation is ready` and displays the Actions URL for your repository.

If a new-resource deployment reports `RequestConflict` after creating the
Azure AI Services account, wait for the current Azure operation to finish.
Rerun setup, choose `1` for an existing resource, and select that account.
Setup will reuse the successful parts instead of creating another account.

## Step 4: Change the number of epochs

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

## Step 5: Validate the change

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

## Step 6: Push and trigger fine-tuning

Commit directly to your repository's `main` branch:

```powershell
git add .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
git commit -m "Exercise 12: compare three training epochs"
git push origin main
```

That push automatically triggers the workflow because a file under the Exercise 12 `config` folder changed. You do not open a pull request, and no instructor merge or approval is required.

## Step 7: Watch the automated experiment

1. Open your repository on GitHub.
2. Select **Actions**.
3. Open the newest workflow run created by your push.

The workflow:

1. Validates the configuration and datasets.
2. Signs in to Azure through repository-specific GitHub OIDC without a client secret.
3. Evaluates ten held-out examples against `medtriage-base`.
4. Uploads the training and validation files through the Azure AI Projects SDK.
5. Calls `fine_tuning.jobs.create()` with the supervised hyperparameters.
6. Writes the Foundry project endpoint and job ID to the workflow summary.
7. Monitors the job until it succeeds, fails, or is cancelled.
8. Uploads the baseline and fine-tuning evidence as a GitHub artifact.

The baseline takes several minutes and fine-tuning takes longer. Do not push another data or configuration experiment while this run is active.

## Step 8: Confirm the Foundry job

Use the **Foundry project endpoint** in this GitHub Actions run summary. If
you reran setup after a failed deployment, an earlier Azure resource may still
exist; its `medtriage-base` deployment does not mean the job ran there. You can
also find the current project endpoint in your repository under **Settings** →
**Secrets and variables** → **Actions** → **Variables** as
`MEDTRIAGE_FOUNDRY_PROJECT_ENDPOINT`.

1. Open the Foundry project matching that endpoint. The account name is the
   hostname before `.services.ai.azure.com`; the project name follows
   `/api/projects/`.
2. Open **Build** → **Fine-tuning** in the current Foundry portal.
3. Match the job ID to the ID in the GitHub Actions summary.
4. Confirm the base model is `gpt-4.1-mini-2025-04-14`.
5. Confirm the job uses three epochs. Check the validated configuration in the
   Actions log; a commit message alone does not change `n_epochs`.

A created job proves that the automation works. The job's fine-tuned model ID
is available after success, but **Models** lists only serving deployments until
you complete Step 10. `medtriage-base` is the base deployment used for the
comparison. A successful job does not prove that the fine-tuned model is
better or safe to deploy.

## Step 9: Evaluate and choose a checkpoint

After training succeeds, compare its checkpoints and held-out results with the
base-model metrics stored in the GitHub artifact. Do not automatically assume
the final checkpoint is best. Select the checkpoint that improves JSON-schema
compliance and urgency-label accuracy without introducing unsafe or incorrect
responses.

Use prompts that were not present in either training or validation data. The
same prompts and system instruction must be used for the base and fine-tuned
deployments so the comparison is fair.

## Step 10: Deploy the selected fine-tuned model

Deployment requires a role that can create model deployments, such as
**Foundry Owner**, or another role containing
`Microsoft.CognitiveServices/accounts/deployments/write`. A learner who can
submit fine-tuning as **Foundry User** might still need deployment permission.

1. Open your Foundry project.
2. Open **Fine-tuning**, and then open the completed Exercise 12 job.
3. Review the job metrics and available checkpoints. Select the evaluated
   checkpoint you want to test.
4. Select **Deploy**, and then select **Serverless**.
5. Enter `medtriage-ft-v1` as the deployment name.
6. Select **Global Standard** as the deployment type.
7. Select a small evaluation capacity within your quota, create the deployment,
   and wait until its status is **Succeeded** on the **Models** page.

If deployment fails because quota is zero, do not retrain the model. Request
deployment quota or select a supported deployment type or region with available
fine-tuned-model quota.

## Step 11: Open the playground and add the system instruction

1. On the completed deployment page, select **Open in playground**. If that
   option is not shown, open **Playgrounds** from the Foundry project.
2. In the deployment selector, choose `medtriage-ft-v1`. Confirm that the
   selected deployment is not the base deployment `medtriage-base`.
3. In **System message** or **System instructions**, replace any existing text
   with this instruction:

```text
You are MedTriage, a hospital symptom triage assistant. Reply ONLY with a single JSON object with the keys urgency (Emergency | Urgent | Routine | Not Applicable), department, reason, next_step. Never give a diagnosis or medication dose. Training demo only - not for clinical use.
```

4. Select **Apply changes**. Select **Continue** if Foundry asks you to confirm
   the update.
5. Start a new chat session so an earlier conversation does not affect the test.

The system instruction is still required after fine-tuning. Fine-tuning teaches
the repeated behavior; the system instruction states the current runtime task
and safety boundary.

## Step 12: Test the fine-tuned model

Enter this prompt in the playground chat, and then select **Send**:

```text
I suddenly developed weakness on the right side of my face and arm, and my speech is unclear. What should I do?
```

The response wording can vary, but verify that:

- The response parses as one JSON object with no Markdown fence or extra text.
- It contains exactly `urgency`, `department`, `reason`, and `next_step`.
- `urgency` is `Emergency`.
- `department` directs the patient to emergency care or an appropriate
  emergency specialty.
- `next_step` clearly says to seek immediate emergency help.
- It does not provide a diagnosis or medication dose.

For a fair comparison, select `medtriage-base`, apply the same system
instruction, and send the same prompt. Compare JSON compliance, urgency-label
correctness, safety, and response length. The fine-tuned model is effective only
when it improves the required behavior on prompts that were not in its training
or validation data.

## Step 13: Test the deployment with Python code

The playground test proves that the deployment works interactively. Now call
the same deployment from Python, as an application would.

### 12.1 Find the endpoint, deployment name, and API key

1. In Foundry, open **Models**, and then open your `medtriage-ft-v1`
   deployment.
2. Select **Get endpoint**, **Code**, or **Use in application**, depending on
   the label shown in your Foundry portal.
3. Copy the OpenAI v1 endpoint. It must end in `/openai/v1/`. For example:

   ```text
   https://finetunning121.services.ai.azure.com/openai/v1/
   ```

4. Copy the **deployment name**. Use the deployed model name shown on this
   page, not the fine-tuning job ID or the base-model name.
5. Copy an API key from the deployment's **Keys and Endpoint** section. If the
   key is not displayed in Foundry, follow the link to the parent Foundry
   resource in the Azure portal, select **Keys and Endpoint**, and copy
   **KEY 1**.

Treat the API key like a password. Use it only in your local copy of the test
file. Never commit or push a real key to GitHub.

### 12.2 Install the dependency

In the Exercise 12 folder, activate the virtual environment you used during
setup, and install the pinned dependencies:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### 12.3 Add your deployment values

Open `scripts/test_deployment.py`. The complete code is shown below. Replace
only the `endpoint`, `deployment_name`, and `api_key` placeholders with the
values copied from Foundry:

```python
from openai import OpenAI


endpoint = "https://<your-resource-name>.services.ai.azure.com/openai/v1/"
deployment_name = "<your-deployment-name>"
api_key = "<your-api-key>"

system_instruction = (
    "You are MedTriage, a hospital symptom triage assistant. Reply ONLY with "
    "a single JSON object with the keys urgency (Emergency | Urgent | Routine "
    "| Not Applicable), department, reason, next_step. Never give a diagnosis "
    "or medication dose. Training demo only - not for clinical use."
)

client = OpenAI(
    base_url=endpoint,
    api_key=api_key,
)

response = client.responses.create(
    model=deployment_name,
    instructions=system_instruction,
    input=(
        "I suddenly developed weakness on the right side of my face and arm, "
        "and my speech is unclear. What should I do?"
    ),
)

print(f"answer: {response.output_text}")
```

For example, the endpoint can look like
`https://finetunning121.services.ai.azure.com/openai/v1/`. Your deployment name
and API key will be different.

The script sends the same system instruction and emergency-triage prompt used
in the playground. It prints `response.output_text`, which is the readable text
returned by the Responses API.

### 12.4 Run the test

```powershell
python .\scripts\test_deployment.py
```

Confirm that the printed answer is one JSON object containing `urgency`,
`department`, `reason`, and `next_step`, and that `urgency` is `Emergency`.

After the test succeeds, immediately replace the real API key in the local
file with `<your-api-key>`. Do not run `git add`, `git commit`, or `git push`
while the real key is present.

## Step 14: Clean up the serving deployment

After testing:

1. Open **Models** in the Foundry project.
2. Select `medtriage-ft-v1`.
3. Select **Delete** and confirm the deletion.
4. Keep the GitHub artifact and evaluation notes as experiment evidence.

Deleting the serving deployment stops its hosting cost. It does not erase the
fine-tuning job evidence stored in GitHub Actions. The exercise is complete.
