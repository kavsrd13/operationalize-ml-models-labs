# Exercise 03: Train a freight regression model

## Goal

Train a freight-cost model locally, then run the same training problem as an
Azure Machine Learning **command job**. You will create or select a resource
group and workspace, register the Olist data asset, create a CPU compute
cluster, submit the job, and inspect its metrics and MLflow model artifact.

This exercise trains a model. It does not register the resulting model as a
workspace model asset or deploy an endpoint.

## Step 1: Clone the code and check prerequisites

Install Python 3.10 or 3.11, Git, Azure CLI, and a notebook editor such as VS
Code. Clone the public repository from a PowerShell terminal. No GitHub CLI
sign-in is needed:

```powershell
git clone https://github.com/kavsrd13/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
python --version
az --version
```

Run the remaining commands from this repository root. If you already cloned
it for Exercises 01 or 02, enter that folder instead of cloning again. To save
your changes in your own GitHub account, use **Use this template** on the
[course repository](https://github.com/kavsrd13/operationalize-ml-models-labs)
and clone your copy instead. In that case, substitute your repository URL in
the `git clone` command above.

The actual code is in [`freight-cost-local.ipynb`](../freight-cost-local.ipynb),
[`src/train.py`](../src/train.py), and [`jobs/train-job.yml`](../jobs/train-job.yml).
The shared resource definitions are
[`olist-data-asset.yml`](../../datasets/olist/olist-data-asset.yml) and
[`compute.yml`](../../00-Shared-Setup-and-Data/scripts/compute.yml).

## Step 2: Prepare the data and local Python environment

Run this once if you have not completed the shared setup in Exercises 01 or 02:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
```

This extracts and checks the nine Olist CSV files, creates `.venv`, installs
Python packages, and registers the **Python (Olist Azure ML)** local notebook
kernel. It does not contact Azure or train a model. Verify the CSVs:

```powershell
(Get-ChildItem '.\datasets\olist\Ecommerce Dataset' -Filter '*.csv').Count
```

The result must be `9`.

## Step 3: Train locally first

Open `03-Freight-Regression-Training/freight-cost-local.ipynb` in VS Code and
select **Python (Olist Azure ML)**. Run through **8. Save the model**. Record
the median baseline, Ridge, and boosting MAE values, and find the saved
`freight_model.joblib`.

The final **9. Try it: Gradio app** section is optional and is not needed for
the Azure job. To run it, first install its extra dependency in `.venv`:

```powershell
.\.venv\Scripts\python.exe -m pip install gradio==6.9.0
```

## Step 4: Select your Azure subscription

If Azure CLI is already signed in, reuse that session. Otherwise run
`az login`. List the enabled subscriptions and copy the ID you intend to use.
Then set these four values in your PowerShell terminal:

```powershell
az account list --query "[?state=='Enabled'].{Name:name,ID:id}" -o table
$SUB = 'YOUR_SUBSCRIPTION_ID'
$RG = 'rg-course-ml'
$WS = 'mlw-course-ml'
$LOCATION = 'eastus'
az account set --subscription $SUB
az account show --query '{name:name,id:id}' -o table
az extension add --name ml --yes
```

Choose a region with quota for `Standard_E4ds_v4`, the training cluster's VM
size. If classmates share a subscription, add your initials to `$RG` and
`$WS` so your workspaces do not collide. Reuse your chosen names in Exercises
04–10.

## Step 5: Create or select a resource group and workspace

For a new course workspace, run:

```powershell
az group create -n $RG -l $LOCATION --subscription $SUB
az ml workspace create -n $WS -g $RG -l $LOCATION --subscription $SUB
```

Azure ML also provisions supporting storage, key vault, and monitoring
resources; it may provision a container registry when needed. If you already
have the intended resource group and workspace, skip both create commands.
In both cases, verify the workspace:

```powershell
az ml workspace show -n $WS -g $RG --subscription $SUB `
  --query '{name:name,location:location}' -o table
```

The name and region must match your choices. You do not need a **compute
instance** for this job; it will use a compute **cluster**.

## Step 6: Register the Olist data asset

The job expects the versioned asset `olist-ecommerce-raw:1`. Resolve the
extracted folder and register it in your workspace:

```powershell
$DATA = (Resolve-Path '.\datasets\olist\Ecommerce Dataset').Path
az ml data create --file '.\datasets\olist\olist-data-asset.yml' `
  --path $DATA -g $RG -w $WS --subscription $SUB
az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS `
  --subscription $SUB --query '{name:name,version:version,type:type}' -o table
```

If version `1` is already registered in this workspace, skip `data create`
and run only `data show`. Azure uploads the nine CSVs to workspace storage;
the job reads this asset instead of your laptop folder.

## Step 7: Create the training compute cluster

The shared definition uses `Standard_E4ds_v4`, one node during training, and
zero nodes when idle. Create `course-cpu` once:

```powershell
az ml compute create --file '.\00-Shared-Setup-and-Data\scripts\compute.yml' `
  -g $RG -w $WS --subscription $SUB
az ml compute show -n course-cpu -g $RG -w $WS `
  --subscription $SUB --query '{name:name,size:size,type:type}' -o table
```

If `course-cpu` already exists, skip `compute create` and run `compute show`.
Wait until provisioning succeeds before submitting the job. The first job
can take extra time while the node starts.

## Step 8: Read the command job definition

Open `03-Freight-Regression-Training/jobs/train-job.yml` and identify its
five essential parts:

1. `code: ../src` uploads `src/train.py`, not the local notebook.
2. `command` runs `python train.py` with data and model parameters.
3. `olist_data` mounts `azureml:olist-ecommerce-raw:1` read-only as `--data`.
4. `environment` supplies a pinned curated scikit-learn environment.
5. `compute: azureml:course-cpu` selects the cluster from Step 7.

In `src/train.py`, find `build_dataset`, the time-based train/test split, the
three model fits, MLflow metric logging, and `outputs/model`. Azure ML will
upload the saved MLflow model **artifact** with the job outputs. It does not
register a workspace model asset automatically.

## Step 9: Submit the Azure ML command job

From the repository root, run the actual Azure ML CLI command. It uploads the
Python code, resolves the data asset and environment, and schedules one job on
`course-cpu`:

```powershell
$JOB = az ml job create --file '.\03-Freight-Regression-Training\jobs\train-job.yml' `
  -g $RG -w $WS --subscription $SUB --query name -o tsv
$JOB
```

Save the printed job name. If Azure reports an error or `$JOB` is empty, fix
that error before continuing; no training job has started.

## Step 10: Monitor and inspect the result

Check the job every few minutes until its status is `Completed`:

```powershell
az ml job show -n $JOB -g $RG -w $WS --subscription $SUB `
  --query '{name:name,status:status,studio_url:studio_url}' -o json
```

Open the returned `studio_url`. In Azure ML Studio, inspect the job's logs,
Metrics, and Outputs. The median baseline, Ridge, and boosting metrics should
all be present. Boosting MAE should be lower than the median baseline. If the
status is `Failed`, read the job logs before changing the code.

Download the result to inspect it locally:

```powershell
$DOWNLOAD = '.\03-Freight-Regression-Training\outputs\azure-job'
New-Item -ItemType Directory -Force -Path $DOWNLOAD | Out-Null
az ml job download -n $JOB -g $RG -w $WS --subscription $SUB `
  --all --download-path $DOWNLOAD
Get-ChildItem $DOWNLOAD -Recurse -Filter metrics.json
Get-ChildItem $DOWNLOAD -Recurse -Filter MLmodel
```

Open `metrics.json` and compare `baseline`, `linear`, and `boosting`. The
`MLmodel` file identifies the model artifact. This exercise leaves that
artifact attached to the job; deployment is a separate exercise.

## Step 11: Keep the workspace connection for Exercise 04

Exercise 04's shared submission helper reads a local, ignored `config.json`.
Record the workspace values you selected without creating anything else:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure `
  --skip-install --subscription $SUB --resource-group $RG --workspace $WS
```

Keep the same workspace, `olist-ecommerce-raw:1` data asset, and `course-cpu`
cluster for [Exercise 04](../../04-Delivery-Time-Pipeline/Instruction/README.md).
Do not delete them or rerun resource creation between exercises. Exercise 08
contains its own training job and does not depend on this run. The
`extended-demo/` folder is supplemental source material with older paths.
