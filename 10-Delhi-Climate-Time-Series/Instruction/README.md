# Exercise 10: Delhi climate time-series regression

## Goal

Create lag-based climate features, train and track a forecasting model locally, then
register, deploy, and invoke it through Azure ML.

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

## Code files

The actual code for this exercise is here:

- [`train_delhi_climate_timeseries_local.ipynb`](../train_delhi_climate_timeseries_local.ipynb)
- [`src/train.py`](../src/train.py)
- [`jobs/train.yml`](../jobs/train.yml)
- [`data/train.yml`](../data/train.yml)
- [`data/test.yml`](../data/test.yml)
- [`deploy/score.py`](../deploy/score.py)
- [`deploy/endpoint.yml`](../deploy/endpoint.yml)
- [`deploy/deployment.yml`](../deploy/deployment.yml)
- [`deploy/conda.yaml`](../deploy/conda.yaml)
- [`deploy/sample-request.json`](../deploy/sample-request.json)
- [`DailyDelhiClimateTrain.csv`](../DailyDelhiClimateTrain.csv)
- [`DailyDelhiClimateTest.csv`](../DailyDelhiClimateTest.csv)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Local route

1. Install the local Python packages and notebook kernel from the cloned root:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
   ```

   Open `../train_delhi_climate_timeseries_local.ipynb` with the **Python (Olist Azure ML)** kernel. Set the
   notebook working directory to this exercise folder so its CSV paths resolve.
2. In a second PowerShell window at the cloned repository root, start MLflow
   and leave that window open:

   ```powershell
   New-Item -ItemType Directory -Force .\mlruns | Out-Null
   .\.venv\Scripts\mlflow.exe server --host 127.0.0.1 --port 5000 `
     --backend-store-uri sqlite:///mlruns/mlflow.db `
     --default-artifact-root ./mlruns
   ```

3. Run every notebook cell in order. It loads the train and test CSVs, creates
   lag-one features, and logs metrics. Open `http://127.0.0.1:5000` to inspect
   the run, then stop the server with Ctrl+C.

## Create or reuse Azure resources for this lab

The local route above needs no Azure resources. For the Azure route, stay at the cloned repository root and run these commands. Replace the four variables with your subscription and preferred names. The same generic `course-cpu` cluster can serve later labs; bootstrap creates the Olist raw asset because the repository setup is shared, even though this lab trains on its own data.

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
```

Check regional quota for `Standard_E4ds_v4` before creating the cluster and `Standard_D2ds_v5` before deploying the endpoint.


## Azure route

Use the Azure ML workspace and `course-cpu` cluster created above.
From the collection root, register the two CSVs once as named assets, then
submit the command job. It creates lag-one features and logs test MAE/RMSE.

```powershell
az ml data show -n course-delhi-train -v 1 -g $RG -w $WS 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  az ml data create -f .\10-Delhi-Climate-Time-Series\data\train.yml `
    -g $RG -w $WS
}
az ml data show -n course-delhi-test -v 1 -g $RG -w $WS 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  az ml data create -f .\10-Delhi-Climate-Time-Series\data\test.yml `
    -g $RG -w $WS
}
az ml data show -n course-delhi-train -v 1 -g $RG -w $WS
az ml data show -n course-delhi-test -v 1 -g $RG -w $WS
$JOB = az ml job create --file .\10-Delhi-Climate-Time-Series\jobs\train.yml `
  --resource-group $RG --workspace-name $WS --query name -o tsv
az ml job show -n $JOB -g $RG -w $WS --query status -o tsv
```

Repeat the status command until it says `Completed`; if streaming fails, inspect
logs in Studio. Inspect metrics and `outputs/model`, then register it as a
new version of `course-delhi-climate-model`:

```powershell
$MODEL_VERSION = az ml model create -n course-delhi-climate-model --type mlflow_model `
  --path "azureml://jobs/$JOB/outputs/artifacts/paths/outputs/model/" `
  -g $RG -w $WS --query version -o tsv
Write-Host "Registered model version $MODEL_VERSION"
```

The older interactive Azure notebook
assumes a pre-existing folder data asset and nearby `config.json`; use the command job
for the reproducible student path.

For serving, set a globally unique endpoint name. The deployment uses the model
version returned above. From the collection root:

```powershell
$ENDPOINT = 'YOUR_GLOBALLY_UNIQUE_ENDPOINT_NAME'
az ml online-endpoint create -f .\10-Delhi-Climate-Time-Series\deploy\endpoint.yml `
  --set name=$ENDPOINT -g $RG -w $WS
az ml online-deployment create -f .\10-Delhi-Climate-Time-Series\deploy\deployment.yml `
  --set endpoint_name=$ENDPOINT model=azureml:course-delhi-climate-model:$MODEL_VERSION `
  -g $RG -w $WS
az ml online-endpoint update -n $ENDPOINT --traffic blue=100 `
  -g $RG -w $WS
az ml online-endpoint invoke -n $ENDPOINT `
  --request-file .\10-Delhi-Climate-Time-Series\deploy\sample-request.json `
  -g $RG -w $WS
az ml online-endpoint delete -n $ENDPOINT --yes `
  -g $RG -w $WS
```

The explicit scoring script and inference environment passed a live East US
deployment and sample invocation on 11 November 2026. The sample returned a
temperature prediction. The custom image build took several minutes. See the
standalone validation report in the repository root.

## Finish and clean up the shared Azure setup

Exercises 03–10 are now complete. First confirm the Delhi endpoint deletion
has finished. Then delete the single course resource group created in Exercise
03. This removes the workspace, scale-to-zero cluster, storage, registered
assets, models, and supporting resources together:

```powershell
Write-Host "Deleting the shared course resource group: $RG"
az group delete --name $RG --subscription $SUB --yes
az group exists --name $RG --subscription $SUB
```

The final command must print `false`. Check the displayed resource-group name
before running the delete command; never substitute a production resource
group.
