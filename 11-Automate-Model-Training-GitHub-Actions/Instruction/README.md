# Exercise 11: Automate Azure ML training with GitHub Actions

In this exercise, you provision a complete Azure Machine Learning training
environment with Bicep and use GitHub Actions to train the Olist freight-cost
model. GitHub authenticates to Azure with OpenID Connect (OIDC), so the
repository does not store an Azure client secret.

The end-to-end path is:

```text
Push training change to your repository's main branch
    -> GitHub Actions signs in to Azure with OIDC
    -> workflow validates the workspace, data asset, and compute cluster
    -> workflow submits an Azure ML command job
    -> Azure ML mounts the registered Olist data on course-cpu
    -> train.py trains and compares three models
    -> Azure ML stores metrics, plots, and the MLflow model
```

## What this exercise creates

The setup uses generic, reusable names. The resource-group and workspace names
come from your answers; supporting names are derived consistently.

| Item | Default or pattern | Purpose |
|---|---|---|
| Resource group | `rg-course-ml` | Contains every Azure resource for the lab. Use a unique suffix in a shared subscription. |
| Azure ML workspace | `mlw-course-ml` | Stores jobs, assets, metrics, models, and experiment metadata. |
| Storage account | `stcourse<unique-suffix>` | Holds uploaded data, job code, outputs, and model files. |
| Key vault | `kv-course-<unique-suffix>` | Stores workspace-managed secrets and datastore credentials. |
| Log Analytics | `log-course-<unique-suffix>` | Stores platform monitoring data. |
| Application Insights | `appi-course-<unique-suffix>` | Provides workspace telemetry. |
| Training cluster | `course-cpu` | Runs the Azure ML command job on `Standard_E4ds_v4`, with 0–1 dedicated Linux nodes. |
| GitHub managed identity | `id-course-github` | Lets the GitHub workflow request short-lived Azure tokens. |
| Federated credential | `github-main` | Trusts only the `main` branch of your student repository. |
| Workspace role | AzureML Data Scientist | Lets the GitHub identity read assets and submit/monitor jobs without managing the workspace or compute. |
| Data asset | `olist-ecommerce-raw:1` | A versioned `uri_folder` containing the nine original Olist CSV files. |

The Bicep deployment creates the resource group and the first ten Azure items.
After deployment, `setup.ps1` uploads and registers the data asset through the
Azure ML CLI.

**This lab does not create a compute instance.** A compute instance is an
interactive development machine. You edit code locally and GitHub submits the
job, so only the scale-to-zero `course-cpu` training cluster is required.

The workspace can create service-managed storage containers and system
datastores inside the named storage account. Because the job uses a curated
Azure ML environment, no dedicated container registry is created by this
template.

## What data and compute the training job uses

The exact cloud job definition is
`11-Automate-Model-Training-GitHub-Actions/jobs/train-job.yml`.

| Job setting | Value |
|---|---|
| Experiment | `olist-freight-cost` |
| Display name | `freight-cost-gradient-boosting` |
| Code uploaded | `11-Automate-Model-Training-GitHub-Actions/src/` |
| Entry script | `train.py` |
| Data input | `azureml:olist-ecommerce-raw:1` |
| Data delivery | `ro_mount` (read-only mount on the training node) |
| Default compute | `azureml:course-cpu` |
| Runtime environment | Azure ML curated `sklearn-1.5`, version `54` |
| Time split | Before `2018-06-01` for training; on/after that date for testing |

The workflow reads `AZURE_ML_COMPUTE` and overrides the YAML compute value at
submission. Setup writes that variable as `course-cpu`, so the checked value,
submitted value, and created cluster are the same.

`train.py` reads seven files from the mounted nine-file asset: order items,
orders, customers, sellers, products, geolocation, and category translation.
Payments and reviews remain in the raw versioned asset but are not needed for
this freight-cost model. The script compares a median baseline, ridge
regression, and histogram gradient boosting. It logs parameters, metrics,
plots, feature importance, Git commit metadata, and an MLflow-format model.

The GitHub-hosted runner only authenticates, validates resources, and submits
the job. **Model training and data access happen on `course-cpu` inside Azure
ML.** The raw CSV files are not downloaded to the GitHub runner.

## Before you start

You need:

- An Azure subscription where you can create resources and role assignments.
  **Owner** is sufficient. Alternatively, use **Contributor** plus **User
  Access Administrator** at the subscription scope.
- Available regional quota for at least four dedicated-family vCPUs used by
  `Standard_E4ds_v4`. You can pass another compatible VM size to setup if your
  region has different quota.
- A GitHub account that can create and administer a repository from a template.
- Git, Azure CLI, GitHub CLI, PowerShell, and Python installed locally.
- Permission to run billable Azure ML compute. The cluster scales to zero after
  120 seconds when idle, but the training node incurs cost while running.

## Step 1: Create your GitHub copy and clone it

1. Open
   [kavsrd13/operationalize-ml-models-labs](https://github.com/kavsrd13/operationalize-ml-models-labs).
2. Select **Use this template** → **Create a new repository**. Choose your
   GitHub account and give the repository any name, such as `mlops3`.
3. Clone your GitHub copy without signing in to GitHub CLI. Replace both
   placeholders with your GitHub account and repository name. Git creates a
   local folder with the repository name; enter that folder:

```powershell
git clone https://github.com/<your-github-name>/<your-repository-name>.git
Set-Location .\<your-repository-name>
git switch main
```

For example, if your repository is `kavsrd13/mlops3`, run:

```powershell
git clone https://github.com/kavsrd13/mlops3.git
Set-Location .\mlops3
git switch main
```

4. Confirm you are in the clone you just created, the working tree is clean,
   and `origin` points to your GitHub copy:

```powershell
Get-Location
git status --short
git remote get-url origin
```

`git status --short` must print nothing. Do not continue if it displays modified
files or if the remote URL names a different repository.

You need GitHub CLI authentication only when setup configures secrets and
variables in your student repository. `gh auth login` identifies your GitHub
account; the clone's `origin` URL identifies the repository. Setup reads that
URL automatically, so you never type an owner/repository value.

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

You can check both existing sessions without signing in again:

```powershell
az account show --output table
gh auth status
```

Setup checks these sessions again and reuses them. The GitHub Actions workflow
later obtains its own short-lived Azure token through OIDC when it runs; that
automatic workflow authentication is separate from your local `az login`.

## Step 3: Run the guided setup

Stay at the repository root and run:

```powershell
.\11-Automate-Model-Training-GitHub-Actions\setup.ps1
```

Setup first displays the repository detected from `origin`. It stops if you
are in the course source repository, an unrelated clone, or a branch other
than `main`. Then it shows numbered subscriptions and asks what to enter:

1. Select the Azure subscription by typing the number shown beside it.
2. Press Enter for `eastus`, or type a region where your subscription has the
   required CPU quota.
3. Press Enter for `rg-course-ml`, or use a unique generic name such as
   `rg-course-ml-kd` in a shared subscription.
4. Press Enter for `mlw-course-ml`, or type another generic workspace name.
5. Review the printed subscription, region, resource group, workspace,
   `course-cpu` cluster, data asset, student repository, and OIDC subject.
6. Review the Azure what-if output. It is a preview and does not create
   resources.
7. Type `deploy` when asked to create the displayed resources.

The script detects the GitHub repository from the `origin` remote; it does not
ask you to type the repository name or subscription ID. It also:

- registers required Azure resource providers when necessary;
- deploys the Bicep template;
- extracts and validates the nine CSV files from
  `datasets/olist/Ecommerce Dataset.zip`;
- uploads and registers `olist-ecommerce-raw:1`;
- creates repository-specific OIDC trust for `main`;
- gives `id-course-github` AzureML Data Scientist access only on this workspace;
- writes the required GitHub secrets and variables.

The ignored file
`11-Automate-Model-Training-GitHub-Actions/.lab11.parameters.json` contains
resource identifiers but no passwords.

## Step 4: Verify setup before training

Use the values you selected:

```powershell
$RG = "rg-course-ml"
$WS = "mlw-course-ml"

az ml workspace show -g $RG -n $WS --query "{name:name,location:location}" -o table
az ml compute show -g $RG -w $WS -n course-cpu --query "{name:name,type:type,size:size,min:min_instances,max:max_instances}" -o table
az ml data show -g $RG -w $WS -n olist-ecommerce-raw -v 1 --query "{name:name,version:version,type:type,path:path}" -o yaml
```

Expected results:

- workspace name matches `$WS`;
- compute is `course-cpu`, type `amlcompute`, minimum 0 and maximum 1;
- data is `olist-ecommerce-raw`, version `1`, type `uri_folder`.

Open your student repository on GitHub and select **Settings** → **Secrets and variables** →
**Actions**. Setup creates:

| Kind | Name | Purpose |
|---|---|---|
| Secret | `AZURE_CLIENT_ID` | Client ID of `id-course-github`. |
| Secret | `AZURE_TENANT_ID` | Selected Azure tenant. |
| Secret | `AZURE_SUBSCRIPTION_ID` | Selected subscription. |
| Variable | `AZURE_RESOURCE_GROUP` | Resource group selected during setup. |
| Variable | `AZURE_ML_WORKSPACE` | Workspace selected during setup. |
| Variable | `AZURE_ML_COMPUTE` | `course-cpu`. |
| Variable | `ENABLE_AZURE_TRAINING` | `true`; allows the workflow job to run. |

There is no `AZURE_CREDENTIALS` client-secret JSON. OIDC exchanges the GitHub
token for a short-lived Azure token at workflow runtime.

If your repository's **Actions** page asks you to enable workflows, enable them before
continuing.

## Step 5: Review the files that control training

Open these files:

- `.github/workflows/train-freight.yml`: authentication, validation, job
  submission, polling, and triggers.
- `11-Automate-Model-Training-GitHub-Actions/jobs/train-job.yml`: data,
  environment, compute, command, and hyperparameters.
- `11-Automate-Model-Training-GitHub-Actions/src/train.py`: data preparation,
  training, evaluation, MLflow logging, and model saving.

The workflow runs manually or after a push to `main` changes the Lab 11 job
definition or source folder. Documentation and workflow-maintenance commits do
not start a billable training run.

## Step 6: Make the learner change

Open
`11-Automate-Model-Training-GitHub-Actions/jobs/train-job.yml`. Change:

```yaml
max_iter: 600
```

to:

```yaml
max_iter: 650
```

Review only that intended change:

```powershell
git diff -- .\11-Automate-Model-Training-GitHub-Actions\jobs\train-job.yml
```

## Step 7: Push and trigger the workflow

Commit directly to your student repository's `main` branch:

```powershell
git add .\11-Automate-Model-Training-GitHub-Actions\jobs\train-job.yml
git commit -m "Exercise 11: increase freight training iterations"
git push origin main
```

No pull request, branch-protection rule, instructor approval, or client secret
is required. The path-filtered push starts **Train freight model in Azure ML**.

## Step 8: Follow the GitHub Actions run

1. Open your student repository on GitHub.
2. Select **Actions**.
3. Open the newest **Train freight model in Azure ML** run created by your push.

The workflow performs these operations in order:

1. Checks out the exact Git commit.
2. Requests an OIDC token and signs in through `id-course-github`.
3. Installs the Azure ML CLI extension.
4. Removes accidental whitespace from the resource variables.
5. Verifies the workspace, selected compute, and
   `olist-ecommerce-raw:1` data asset.
6. Submits `train-job.yml`, overriding compute with the verified
   `AZURE_ML_COMPUTE` value.
7. Adds the Git commit and workflow URL to the Azure ML job environment and
   tags.
8. Polls Azure ML until the job completes or fails.
9. Writes the job name, data asset, compute name, commit, and Studio link to the
   workflow summary.

The first run can wait several minutes while `course-cpu` scales from zero and
Azure ML prepares the curated environment.

## Step 9: Validate the Azure ML training job

Use the Studio link in the workflow summary, or open the workspace in Azure ML
studio and select **Jobs**.

Verify:

- **Status** is **Completed**.
- **Experiment** is `olist-freight-cost`.
- **Code** came from the pushed Git commit.
- **Input** is data asset `olist-ecommerce-raw`, version `1`, mounted read-only.
- **Compute** is the cluster stored in `AZURE_ML_COMPUTE`, normally
  `course-cpu`.
- **Parameters** show `max_iter` as `650`.
- **Metrics** include baseline, linear, and boosting MAE/RMSE/R2 values plus
  `mae_improvement_vs_baseline`.
- **Tags** include `git_commit` matching the GitHub commit.
- **Outputs + logs** contain `outputs/metrics.json`, `outputs/model/`, plots,
  and feature importance artifacts.

The saved MLflow model is a job output and MLflow artifact. This exercise does
not automatically register or deploy the model; those are separate release
decisions after evaluation.

## Step 10: Understand reruns

Use **Run workflow** on the Actions page only when you intentionally want to
rerun the same configuration. A manual run is billable just like a push run.
Do not repeatedly push while another training run is active; the workflow
queues runs instead of cancelling an active experiment.

## Step 11: Clean up

When the class no longer needs the workspace, delete the dedicated resource
group. This removes the workspace, cluster, storage, monitoring resources, and
GitHub identity together:

```powershell
az group delete --name $RG --yes
az group exists --name $RG
```

Wait until the second command returns `false`. Resource-group deletion is
asynchronous. Deleting a soft-deleted key vault can leave its globally unique
name reserved for the retention period.

Delete the three Azure secrets and four Azure variables from the repository if the
repository will be reused for a different subscription.

## Troubleshooting

- **Setup cannot read the repository:** confirm `git remote -v` points to your
  student repository and `gh auth status` shows its owner account.
- **Setup unexpectedly asks for a subscription ID or `OWNER/REPO`:** you are
  running an old setup script or are in the wrong clone. Run `Get-Location`,
  `git status --short`, and `git remote get-url origin`; then return to the
  clean folder named after your GitHub repository created in Step 1.
- **Setup says administrator access is required:** run setup from a repository
  created under your account with **Use this template**, not the instructor's source repository.
- **OIDC login fails:** rerun setup from the same student repository. OIDC trust is specific
  to the repository and `main` branch.
- **Compute quota fails:** choose another region or rerun setup with a VM size
  available in your subscription, for example
  `-VmSize '<available-cpu-sku>'`.
- **Workflow cannot find data:** confirm version `1` exists in the same
  workspace configured by `AZURE_ML_WORKSPACE`.
- **Workflow cannot find compute:** confirm `AZURE_ML_COMPUTE` exactly matches
  an existing Azure ML compute cluster. Setup uses `course-cpu`.
- **The workflow is skipped:** confirm `ENABLE_AZURE_TRAINING` equals the
  lowercase value `true` in your repository's Actions variables.
- **The first job waits in Starting or Preparing:** the zero-node cluster must
  allocate a VM and prepare the curated environment. Check regional quota and
  Azure ML job logs before resubmitting.
