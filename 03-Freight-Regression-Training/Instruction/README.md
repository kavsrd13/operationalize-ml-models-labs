# Exercise 03: Train a freight regression model

## Goal

Predict item freight cost from checkout-time features, compare a median baseline,
Ridge, and gradient boosting, and inspect the MLflow model created by Azure ML.

## Fork and clone the public repository

Install Python 3.10 or 3.11, Git, Azure CLI, and a notebook editor. The public course repository can be inspected or cloned without a GitHub login:

```powershell
git clone https://github.com/kavsrd13/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
```

To save your exercise work in your own GitHub account, sign in at [GitHub](https://github.com/), open [the course repository](https://github.com/kavsrd13/operationalize-ml-models-labs), select **Fork**, and then select **Create fork**. Clone your fork instead of the upstream repository:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
git remote add upstream https://github.com/kavsrd13/operationalize-ml-models-labs.git
git remote -v
```

No `gh auth login` command is needed for cloning. GitHub sign-in is required only to create the fork or push changes to it.

## Create or reuse Azure resources for this lab

Set your own subscription, resource group, workspace, and region. The commands
create the group and workspace if needed, install the shared Olist asset, and
create one scale-to-zero training cluster named `course-cpu`. Reuse the same
names in later labs. Check regional quota for `Standard_E4ds_v4`.

```powershell
$SUB = 'YOUR_SUBSCRIPTION_ID'
$RG = 'rg-course-ml'
$WS = 'mlw-course-ml'
$LOCATION = 'eastus'
az login
az account set --subscription $SUB
az extension add --name ml --yes
az group create -n $RG -l $LOCATION
az ml workspace show -n $WS -g $RG --subscription $SUB 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  az ml workspace create -n $WS -g $RG -l $LOCATION --subscription $SUB
}
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py `
  --subscription $SUB --resource-group $RG --workspace $WS --create-cluster
az ml compute show -n course-cpu -g $RG -w $WS --query name -o tsv
az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS --query name -o tsv
```

## Code files

The actual code for this exercise is here:

- [`freight-cost-local.ipynb`](../freight-cost-local.ipynb)
- [`src/train.py`](../src/train.py)
- [`jobs/train-job.yml`](../jobs/train-job.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Use the `$RG` and `$WS` values from the Azure setup section above.
2. Confirm the shared resources:

   ```powershell
   az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS --query name -o tsv
   az ml compute show -n course-cpu -g $RG -w $WS --query name -o tsv
   ```

3. Read `../src/train.py` in execution order: input CSVs, joins, checkout-time
   features, time split, baseline, fitted models, and metrics. Find the `--data`
   argument and `outputs/model` artifact.
4. Open `../freight-cost-local.ipynb` with the Olist kernel. Run every cell;
   record baseline MAE and fitted-model MAE.
5. Review `../jobs/train-job.yml`. It points to the shared data asset and compute.
6. Preview and submit one Azure ML job:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\submit.py freight --dry-run
   python .\00-Shared-Setup-and-Data\scripts\submit.py freight
   ```

7. Copy the returned job name. Stream logs and check final status:

   ```powershell
   az ml job stream -n YOUR_JOB_NAME -g $RG -w $WS
   az ml job show -n YOUR_JOB_NAME -g $RG -w $WS --query status -o tsv
   ```

   If this CLI version reports `Incorrect padding` while streaming, the job
   can still finish normally. Use `az ml job show` for its final status and
   `az ml job download -n YOUR_JOB_NAME -g $RG -w $WS --all` to inspect logs,
   `outputs/metrics.json`, and the model folder.

8. In Studio compare MAE against the median baseline, inspect the prediction
   plot and `outputs/model`, and identify the held-out time period. The model
   output is used by exercise 08.

The `../extended-demo/` folder is supplemental source material with older paths.
