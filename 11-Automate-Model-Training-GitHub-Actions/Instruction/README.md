# Exercise 11: GitHub training automation with Bicep and MLflow

## Outcome

Provision a reusable Azure ML environment, push a training change to GitHub, and compare the resulting MLflow experiments. Infrastructure setup runs once. Training runs automatically for each relevant push to main. This exercise is independent: it includes cloning, infrastructure, data registration, training and results. Model serving is covered in Exercise 08.

This lab uses industry practices: versioned infrastructure, a deployment preview, passwordless GitHub OIDC, a workspace-scoped training identity, versioned data, and commit-linked experiments. It uses public service endpoints for classroom simplicity; private networking and production deployment approvals are outside this lab.

## 1. Prepare access and tools

Install Git, GitHub CLI, Azure CLI with Bicep, and Python 3.10 or 3.11. You need access to the private course repository and permission to create a private repository. For infrastructure setup, use an Azure account permitted to create resource groups and resources and assign roles (for example subscription Owner). An instructor can perform setup for students who only have workspace access. Ensure the selected region has at least four available E-series v4 CPU cores for Standard_E4ds_v4, or pass an available size using -VmSize.

```powershell
gh auth login
az login
az bicep install
gh repo clone kavsrd13/operationalize-ml-models-labs
Set-Location .\operationalize-ml-models-labs
```

Clone first because the Bicep template and setup script are in the repository. All following commands run from this repository root.

## 2. Create your private student repository

```powershell
$OWNER = gh api user --jq '.login'
$REPO = 'my-azure-ml-training-lab'
$LAB_REPO = "$OWNER/$REPO"
gh repo create $LAB_REPO --private --source . --remote student --push
```

Choose a new repository name if that name already exists. Keep main as the default branch. The initial workflow may be skipped: setup enables training only after resources and access are ready. The student remote points to your repository; origin still points to the instructor repository.

## 3. Run guided setup

```powershell
.\11-Automate-Model-Training-GitHub-Actions\setup.ps1 -GitHubRepo $LAB_REPO
```

The script asks for subscription, region, resource group and workspace. Use a dedicated course group, for example rg-course-anna and mlw-course-anna. Keep those names for subsequent labs. Students sharing a subscription need separate groups and workspaces.

Compute stays course-cpu. Storage, Key Vault and monitoring names are generated consistently from the resource group, so rerunning setup uses the same names. Read the Bicep preview before typing deploy. Do not point this template at an unrelated existing workspace: workspace storage and Key Vault associations cannot be changed in place.

The script performs these steps:

1. Checks Azure and GitHub sign-in and your repository permissions.
2. Saves the deployment parameters in an ignored local .lab11.parameters.json file.
3. Runs Bicep what-if to show the resources and role assignments.
4. Creates the resource group, storage, Key Vault, monitoring, workspace and course-cpu cluster (minimum zero nodes, maximum one).
5. Creates a managed identity with GitHub federation for this repository's main branch and AzureML Data Scientist access on this workspace. No application password is created.
6. Extracts the included Olist ZIP and registers olist-ecommerce-raw:1. Existing version 1 is reused.
7. Sets GitHub's Azure IDs and workspace variables, then enables automatic training.
8. Prints GitHub Actions and Azure ML Studio links.

For repeatable unattended provisioning, pass the same choices explicitly. Preview first; -Yes accepts deployment without the interactive question.

```powershell
.\11-Automate-Model-Training-GitHub-Actions\setup.ps1 `
  -SubscriptionId YOUR_SUBSCRIPTION_ID `
  -ResourceGroup rg-course-anna -Workspace mlw-course-anna `
  -Location eastus -GitHubRepo $LAB_REPO -PreviewOnly
```

Rerun without -PreviewOnly to deploy. Keep the same region and names on subsequent runs. The saved parameter file can also be reviewed and supplied to an infrastructure deployment pipeline; personal login and terminal prompts are the classroom bootstrap, while production pipelines supply approved parameters noninteractively.

## 4. Locate and understand the actual code

- [setup.ps1](../setup.ps1): guided provisioning and GitHub configuration.
- [infra/main.bicep](../infra/main.bicep): subscription deployment and resource group.
- [infra/resources.bicep](../infra/resources.bicep): workspace, cluster, identity and GitHub trust. Supporting resources reuse the shared Bicep modules included in this clone.
- [src/train.py](../src/train.py): feature preparation and baseline, ridge and gradient boosting models.
- [jobs/train-job.yml](../jobs/train-job.yml): pinned training environment, dataset version, compute and parameters.
- [GitHub workflow](../../.github/workflows/train-freight.yml): push trigger, Azure login, job submission and final status checking.

The workflow must remain in .github/workflows at repository root. GitHub submits the job; the model actually trains on Azure ML course-cpu. Azure ML supplies the MLflow tracking connection to the job.

## 5. Run a baseline from GitHub

```powershell
gh workflow run train-freight.yml --repo $LAB_REPO --ref main
gh repo view $LAB_REPO --web
```

Open Actions and select the run. Wait for the Azure ML job to finish; initial compute startup can take several minutes. The GitHub summary links to Studio and records the Git commit and job name. A green GitHub run means Azure ML reported Completed.

In Studio, open Jobs, experiment olist-freight-cost, then the job. Inspect Metrics and Outputs + logs. Record boosting_mae, boosting_rmse, boosting_r2 and mae_improvement_vs_baseline. Confirm parameters include learning_rate and max_iter. MLflow tags include git_commit, github_run_url and data_asset. Artifacts contain prediction plots, feature importance, results/metrics.json and results/model in MLflow format. The model is also retained under outputs/model; saving a model does not automatically register a model version or deploy an endpoint.

## 6. Change the model and push

Open jobs/train-job.yml in Lab 11. Change learning_rate from 0.05 to 0.10, then:

```powershell
git add .\11-Automate-Model-Training-GitHub-Actions\jobs\train-job.yml
git commit -m "Experiment: compare learning rate 0.10"
git push student main
```

Open Actions. A new run starts automatically; do not click Run workflow again. Select both jobs in the Studio experiment to compare metrics. Check that the MLflow git_commit tag matches each GitHub commit. Record whether MAE improved; lower is better. A parameter change does not guarantee improvement.

## 7. Validate what you learned

- Both GitHub runs are green and both Azure ML jobs are Completed.
- Each job references a different commit and the same versioned dataset.
- The second run records learning_rate=0.10.
- Metrics, plots, feature importance and the model artifact are visible.
- A documentation-only change does not start training because the workflow watches only its own file, Lab 11 training source and job YAML.

## 8. Stop automatic training and clean up

```powershell
gh variable set ENABLE_AZURE_TRAINING --body false --repo $LAB_REPO
```

Let running jobs complete, or cancel them in Azure ML Studio. Cancelling GitHub alone does not cancel a submitted Azure job. course-cpu scales to zero when idle; storage and monitoring can still incur charges. Keep the shared course resources for later labs. When the course is finished, remove the dedicated course resource group through Azure Portal after checking its contents; this also removes its managed identity and workspace role. Remove the three AZURE_* repository secrets and the workspace/group/training variables from GitHub Settings when access is no longer needed.

## Troubleshooting

- Setup permission error: an administrator must provision resources and role assignments; training uses a narrower workspace role.
- Quota error: select a region and VM size with capacity, then rerun setup with the same intended names.
- AADSTS700213: GitHub's presented subject must match exactly. New repositories use numeric owner/repository IDs. Older, renamed, transferred or customized repositories can differ. Rerun setup with -OidcSubject followed by the exact presented subject from the failed login. See [GitHub OIDC reference](https://docs.github.com/en/actions/reference/security/oidc).
- First-run authorization error: role assignments can take a few minutes to propagate. Retry the workflow after propagation.
- Workflow skipped: verify ENABLE_AZURE_TRAINING is true in your student repository.
- No push run: verify you pushed to student main and changed a watched path.
- Training failed: open the Azure job's user_logs/std_log.txt. GitHub reports the Azure final status.
- GitHub timed out or was cancelled: inspect the Azure job before retrying to avoid duplicate jobs.

## Validation status

The previous training workflow was live-tested on 11 November 2026. The Bicep-managed identity setup and additional MLflow artifacts are a new revision. See LAB11_VALIDATION.md in this exercise for the checks actually completed; previous live evidence does not validate the new setup.
