# Exercise 06: Late delivery and Responsible AI

## Goal

Train a late-delivery classifier, register its model, and inspect cohort errors,
feature explanations, and the Responsible AI dashboard.

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

- [`prepare.py`](../prepare.py)
- [`src/train.py`](../src/train.py)
- [`jobs/train.yml`](../jobs/train.yml)
- [`jobs/rai-dashboard.yml`](../jobs/rai-dashboard.yml)
- [`data/train.yml`](../data/train.yml)
- [`data/test.yml`](../data/test.yml)
- [`data/rai-train.yml`](../data/rai-train.yml)
- [`data/rai-test.yml`](../data/rai-test.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Use the `$RG` and `$WS` values from the setup above. Confirm `course-cpu`
   exists.
2. Read `../prepare.py`: identify the label, checkout-time features, full
   train/test split, and smaller stratified dashboard copies.
3. Run the preparation script with the Olist environment:

   ```powershell
   .\.venv\Scripts\python.exe .\06-Late-Delivery-Responsible-AI\prepare.py
   ```

4. Inspect the Parquet and `MLTable` files under `../data`. Register the four
   named assets in the **same** workspace:

   ```powershell
   Get-ChildItem .\06-Late-Delivery-Responsible-AI\data\*.yml | ForEach-Object {
     az ml data create -f $_.FullName -g $RG -w $WS
   }
   ```

5. Submit and monitor the training job:

   ```powershell
   $TRAIN_JOB = az ml job create -f .\06-Late-Delivery-Responsible-AI\jobs\train.yml `
     -g $RG -w $WS --query name -o tsv
   az ml job show -n $TRAIN_JOB -g $RG -w $WS --query status -o tsv
   ```

   Repeat the status command until it says `Completed`. Streaming is optional;
   some Azure CLI versions report `Incorrect padding` after a successful job.

6. In Studio inspect the full future-period classification metrics. When the
   job is `Completed`, register its MLflow output:

   ```powershell
   az ml model create -n olist-late-delivery-rai --type mlflow_model `
     --path "azureml://jobs/$TRAIN_JOB/outputs/artifacts/paths/outputs/model/" `
     -g $RG -w $WS
   ```

7. Check the returned model version. `../jobs/rai-dashboard.yml` references
   version 1; if yours differs, change its `selected_model.path` and
   `construct.inputs.model_info` to the version you just registered.
8. Read `../lab-guide.html` for the dashboard's component flow, then submit:

   ```powershell
   $DASHBOARD_JOB = az ml job create -f .\06-Late-Delivery-Responsible-AI\jobs\rai-dashboard.yml `
     -g $RG -w $WS --query name -o tsv
   az ml job show -n $DASHBOARD_JOB -g $RG -w $WS --query status -o tsv
   ```

   Repeat the status command until it says `Completed`.

9. Open the dashboard in Studio. Compare error and explanation views across
   cohorts. Observed differences alone do not establish causality or a
   fairness violation.

## Next exercise

Keep the same workspace, registered assets, and `course-cpu` cluster. Continue
with [Exercise 07](../../07-Late-Delivery-Hyperparameter-Sweep/Instruction/README.md).
Do not delete the resource group or rerun shared setup.
