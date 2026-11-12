# Exercise 12: Automate Foundry fine-tuning with GitHub Actions

## Outcome

Create or reuse a Microsoft Foundry/Azure AI Services resource, connect a private student GitHub repository to Azure without a client secret, validate a versioned medical-triage dataset, measure the base model, and submit a supervised fine-tuning job after an approved push to `main`.

This exercise is independent of Exercises 00–11. It uses Azure AI Services and Foundry rather than the shared Azure Machine Learning workspace or `course-cpu` cluster.

The automation submits a fine-tuning job; it does not automatically deploy the resulting model. In an industry workflow, deployment follows job completion, checkpoint evaluation, safety review, quota confirmation, and a separate approval.

## Architecture

```text
Student changes versioned data or configuration
                 |
                 v
        Push to GitHub main
                 |
                 v
 GitHub Actions validates the JSONL dataset
                 |
                 v
 GitHub OIDC obtains a short-lived Azure token
                 |
                 v
 Base gpt-4o-mini evaluation is recorded
                 |
                 v
 Training and validation files are uploaded
                 |
                 v
 Microsoft Foundry fine-tuning job is submitted
```

## 1. Check prerequisites and quota

Install Git, GitHub CLI, Azure CLI with Bicep, and Python 3.10 or 3.11. You need:

- A private GitHub repository you administer.
- An Azure subscription in which you can deploy resources and assign roles. Subscription Owner is sufficient for the classroom bootstrap; an administrator can perform setup for learners with narrower access.
- A region and subscription with `gpt-4o-mini` base deployment capacity and fine-tuning quota.
- A qualified reviewer for the medical labels and safety wording before enabling paid training.

Check the tools and sign in with the Azure identity that belongs to the intended tenant:

```powershell
git --version
gh --version
az version
python --version
gh auth login
az login --use-device-code
az bicep install
```

Device-code authentication is completed in the same terminal session that will run setup. A login completed in another machine or agent session does not transfer its Azure CLI token.

## 2. Clone the course code and create a student repository

```powershell
gh repo clone kavsrd13/operationalize-ml-models-labs
Set-Location .\operationalize-ml-models-labs

$OWNER = gh api user --jq '.login'
$REPO = 'my-foundry-finetuning-lab'
$LAB_REPO = "$OWNER/$REPO"
gh repo create $LAB_REPO --private --source . --remote student --push
```

Keep `main` as the default branch. `origin` points to the instructor repository and `student` points to your private exercise repository. Setup automatically detects the repository from Git remotes: it uses `student` when present and otherwise uses `origin`. The detected repository is printed before OIDC configuration; the learner does not type `OWNER/REPOSITORY`.

## 3. Inspect the actual code

- [setup.ps1](../setup.ps1): guided subscription, resource, Bicep and GitHub configuration.
- [infra/main.bicep](../infra/main.bicep): creates a new resource group and delegates new-resource provisioning.
- [infra/resources.bicep](../infra/resources.bicep): creates a new Azure AI Services resource, base deployment, managed identity, OIDC federation and role assignment.
- [infra/existing-main.bicep](../infra/existing-main.bicep): targets the resource group of a selected existing resource without recreating the group.
- [infra/existing-resources.bicep](../infra/existing-resources.bicep): reuses the selected account and adds only the missing lab components.
- [config/finetune.json](../config/finetune.json): model, training tier, epochs, learning-rate multiplier and suffix.
- [scripts/validate_dataset.py](../scripts/validate_dataset.py): deterministic checks before Azure is used.
- [scripts/evaluate_baseline.py](../scripts/evaluate_baseline.py): evaluates ten held-out examples against `medtriage-base`.
- [scripts/submit_finetune.py](../scripts/submit_finetune.py): uploads both datasets and submits the supervised fine-tuning job.
- [GitHub workflow](../../.github/workflows/fine-tune-medtriage.yml): validation, OIDC login, baseline evaluation and submission.

The workflow requests `id-token: write`. Azure trusts only the configured repository and `main` branch. GitHub stores the identity's client ID, tenant ID and subscription ID, but no password, API key or client secret.

## 4. Validate the versioned dataset locally

```powershell
python .\12-Foundry-Fine-Tuning-GitHub-Actions\scripts\validate_dataset.py `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_training_300.jsonl `
  .\12-Foundry-Fine-Tuning-GitHub-Actions\data\medical_triage_validation_300.jsonl
```

Expected result:

```text
Training examples: 255
Validation examples: 45
System prompts: 1
Train/validation overlap: 0
Dataset validation passed.
```

The filenames contain `300`, but the actual split is 255 training and 45 validation examples. The validator also requires exactly `system`, `user`, and `assistant` messages, valid assistant JSON, the four expected output fields, allowed urgency labels, nonblank values, and no identical user questions across the two splits.

Do not enable training merely because structural validation passes. A qualified reviewer must confirm clinical labels, emergency escalation language, jurisdiction, consent to use the data, and absence of personal health information. This is a teaching dataset, not a clinical decision-support system.

## 5. Preview the guided Azure setup

Run the setup from the repository root:

```powershell
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1 -PreviewOnly
```

The script lists every enabled subscription visible to the signed-in Azure user with a number. Enter the displayed number, not the subscription ID. For example, if the intended subscription is shown as `[2]`, enter `2`. Invalid input displays the numbered list again.

After selecting a subscription, the script asks:

```text
[1] Use an existing Azure AI Services / Azure OpenAI resource
[2] Create a new dedicated Azure AI Services resource
[3] Exit setup without deploying anything
```

Every setup run displays this menu. Enter exactly `1`, `2`, or `3`. An invalid entry displays all three choices again. Option `3` stops before Bicep deployment or GitHub configuration.

### Option 1: existing resource

The script lists compatible resources in the selected subscription. Select one by number. It uses the selected resource's group, name and region and does not recreate or retag that resource.

If `medtriage-base` already deploys `gpt-4o-mini` version `2024-07-18`, it is reused. If that deployment is missing, Bicep proposes creating it. If the name belongs to a different model or version, setup stops instead of overwriting it.

### Option 2: new resource

The script asks for a resource group, region and globally unique Azure AI Services name. Defaults are offered, but the learner can enter different names. Bicep proposes the dedicated resource group, Azure AI Services resource and base deployment.

### Resources common to both choices

The preview includes a user-assigned managed identity unique to the student repository, a GitHub OIDC federated credential restricted to `main`, and `Cognitive Services OpenAI Contributor` on only the selected Azure AI resource.

Read the entire `what-if` output. `-PreviewOnly` creates no Azure or GitHub resources.

## 6. Apply the setup

Rerun without `-PreviewOnly`:

```powershell
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1
```

Choose the same subscription and resource strategy. After the preview, the script displays:

```text
[1] Deploy the resources shown above
[2] Show the Bicep what-if preview again
[3] Exit without deploying
```

Enter `1` only when the proposed resources are correct. Enter `2` to inspect the preview again or `3` to stop.

After deployment the script configures these GitHub secrets:

- `MEDTRIAGE_AZURE_CLIENT_ID`
- `MEDTRIAGE_AZURE_TENANT_ID`
- `MEDTRIAGE_AZURE_SUBSCRIPTION_ID`

It also configures the Foundry endpoint, Azure resource names and two safety variables. Both safety variables initially remain `false`, so setup cannot accidentally submit a paid job.

For repeatable setup, pass the resource details explicitly. Subscription selection, resource strategy and final deployment approval remain numbered interactive choices:

```powershell
# Reuse a known resource
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1 `
  -ResourceGroup YOUR_EXISTING_RESOURCE_GROUP `
  -AccountName YOUR_EXISTING_AI_RESOURCE

# Or create a dedicated resource
.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1 `
  -ResourceGroup rg-medtriage-finetuning `
  -Location eastus `
  -AccountName YOUR_GLOBALLY_UNIQUE_NAME
```

## 7. Review and enable the controlled training gates

Only after the required data review, enable both repository variables:

```powershell
gh variable set MEDTRIAGE_DATA_REVIEWED --body true --repo $LAB_REPO
gh variable set ENABLE_MEDTRIAGE_FINETUNING --body true --repo $LAB_REPO
```

These are deliberate cost and safety gates, not credentials. If either value is not exactly `true`, the workflow is skipped.

## 8. Change the fine-tuning configuration and push

Open `12-Foundry-Fine-Tuning-GitHub-Actions/config/finetune.json`. Change the suffix to a short identifier for your experiment, while leaving the reviewed model and hyperparameters unchanged for the first run. Then commit only the Exercise 12 change:

```powershell
git add .\12-Foundry-Fine-Tuning-GitHub-Actions\config\finetune.json
git commit -m "Exercise 12: submit reviewed fine-tuning experiment"
git push student main
```

The push triggers the workflow because the configuration is a watched path. Open the run:

```powershell
gh run list --workflow fine-tune-medtriage.yml --repo $LAB_REPO
gh repo view $LAB_REPO --web
```

The workflow first validates the files, then obtains a short-lived Azure token through OIDC. It evaluates ten validation examples on `medtriage-base`, uploads both JSONL files, waits for file processing, and submits one supervised fine-tuning job.

## 9. Verify the submitted job

In the GitHub run summary, record:

- Git commit SHA.
- Foundry fine-tuning job ID.
- Baseline JSON-schema compliance rate.
- Baseline urgency-label match rate.

Download the `fine-tuning-job` workflow artifact and inspect `baseline_metrics.json` and `fine_tuning_job.json`. Then open the selected Azure AI Services/Foundry resource and locate the fine-tuning job. Confirm that the job ID matches GitHub and monitor it to a terminal status.

A green GitHub workflow means that the job was submitted successfully; it does not mean that the asynchronous Foundry training job has completed or that the resulting model is safe to deploy.

## 10. Stop automatic paid submissions

Immediately close the training gate after the intended submission:

```powershell
gh variable set ENABLE_MEDTRIAGE_FINETUNING --body false --repo $LAB_REPO
```

Keep `MEDTRIAGE_DATA_REVIEWED` aligned with the currently committed dataset. Set it back to `false` whenever the training or validation data changes and require another review.

## 11. Cleanup

If you created a dedicated resource group for this exercise, first confirm that it contains no unrelated resources. When the lab and any required evaluation are finished, delete that dedicated group through Azure Portal or your organization's approved cleanup process.

If you reused an existing shared resource, do not delete its resource group or Azure AI account. Remove only the Exercise 12 identity, role assignment, and any base deployment that this exercise created and that no other workload uses. Also remove the `MEDTRIAGE_*` GitHub secrets and variables when the repository no longer needs Azure access.

Deletion is intentionally not automated by the setup script because the existing-resource path may target shared infrastructure.

## Troubleshooting

- `AADSTS50020` or `AADSTS500341`: the Azure CLI is using an identity from the wrong tenant or a stale account. Run `az logout`, sign in to the subscription's tenant in the same terminal, and verify `az account show` before rerunning setup.
- `./setup.ps1` is not recognized: check `Get-Location` and `Test-Path .\setup.ps1`. From the repository root, run `.\12-Foundry-Fine-Tuning-GitHub-Actions\setup.ps1`; from inside the Exercise 12 folder, run `.\setup.ps1`. The script does not change the terminal's current directory, so it can be rerun from the same location.
- Wrong GitHub repository detected: setup prefers the remote named `student`; otherwise it uses `origin`. Check `git remote -v`. Add or correct the `student` remote before rerunning setup.
- No resources listed under Existing: confirm the selected subscription and that the account can read Azure AI Services/OpenAI resources; otherwise choose New.
- Fine-tuning quota error: the selected region/subscription lacks quota for the configured model or training type. Use a resource in an approved region with quota or request quota before enabling the workflow.
- Base deployment quota error: choose an existing compatible `medtriage-base` deployment or a region with base-model capacity.
- OIDC login failure: compare the subject in the GitHub error with the subject printed by setup. Rerun setup with `-OidcSubject 'THE_EXACT_SUBJECT'` if the repository uses a customized subject format.
- First-run authorization error: Azure role propagation can take several minutes. Retry the same workflow after propagation; verify that a previous fine-tuning job was not already submitted.
- Workflow skipped: both `ENABLE_MEDTRIAGE_FINETUNING` and `MEDTRIAGE_DATA_REVIEWED` must equal `true` in the student repository.
- Workflow green but training still running: GitHub submits the asynchronous job and preserves its ID; monitor the job in Foundry.

## Validation status

The dataset validator, Python syntax, YAML parsing, PowerShell syntax, and both Bicep paths have been checked locally. The supplied files contain 255 training and 45 validation records with zero identical user questions across splits. The revised Exercise 12 setup and workflow have not yet been run end to end against a learner's Azure subscription, so live quota, model availability, OIDC subject policy, role propagation, training completion and model quality remain tenant-specific validation steps.
