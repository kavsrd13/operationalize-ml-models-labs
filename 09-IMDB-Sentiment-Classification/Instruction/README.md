# Exercise 09: IMDB sentiment classification

## Goal

Train and track a text sentiment classifier locally, then repeat the lifecycle with an
Azure ML data asset, model registration, managed deployment, and invocation.

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

- [`train_imdb_sentiment_local.ipynb`](../train_imdb_sentiment_local.ipynb)
- [`src/train.py`](../src/train.py)
- [`jobs/train.yml`](../jobs/train.yml)
- [`data/imdb.yml`](../data/imdb.yml)
- [`deploy/score.py`](../deploy/score.py)
- [`deploy/endpoint.yml`](../deploy/endpoint.yml)
- [`deploy/deployment.yml`](../deploy/deployment.yml)
- [`deploy/conda.yaml`](../deploy/conda.yaml)
- [`deploy/sample-request.json`](../deploy/sample-request.json)
- [`IMDB Dataset.csv`](../IMDB%20Dataset.csv)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Local route

1. Install the local Python packages and notebook kernel from the cloned root:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
   ```

   Open `../train_imdb_sentiment_local.ipynb` with the **Python (Olist Azure ML)** kernel. Set the
   notebook working directory to this exercise folder so its CSV paths resolve.
2. In a second PowerShell window at the cloned repository root, start MLflow
   and leave that window open:

   ```powershell
   New-Item -ItemType Directory -Force .\mlruns | Out-Null
   .\.venv\Scripts\mlflow.exe server --host 127.0.0.1 --port 5000 `
     --backend-store-uri sqlite:///mlruns/mlflow.db `
     --default-artifact-root ./mlruns
   ```

3. Run every notebook cell in order. It loads `../IMDB Dataset.csv`, trains
   the classifier, and logs metrics. Open `http://127.0.0.1:5000` to inspect
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
From the collection root, register the CSV once as a named asset, then submit
the command job. The `../src/train.py` source has the
same TF-IDF and logistic regression flow as the local notebook.

```powershell
az ml data show -n course-imdb-data -v 1 -g $RG -w $WS 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  az ml data create --file .\09-IMDB-Sentiment-Classification\data\imdb.yml `
    --resource-group $RG --workspace-name $WS
}
az ml data show -n course-imdb-data -v 1 -g $RG -w $WS
$JOB = az ml job create --file .\09-IMDB-Sentiment-Classification\jobs\train.yml `
  --resource-group $RG --workspace-name $WS --query name -o tsv
az ml job show -n $JOB -g $RG -w $WS --query status -o tsv
```

Repeat the status command until it says `Completed`; if streaming fails, inspect
logs in Studio. Inspect `test_accuracy` and `outputs/model`, then register
that artifact as a new version of `course-imdb-sentiment-model` before deployment:

```powershell
$MODEL_VERSION = az ml model create -n course-imdb-sentiment-model --type mlflow_model `
  --path "azureml://jobs/$JOB/outputs/artifacts/paths/outputs/model/" `
  -g $RG -w $WS --query version -o tsv
Write-Host "Registered model version $MODEL_VERSION"
```
The older `../train_imdb_sentiment_azureml.ipynb` shows an interactive route, but its
asset and workspace setup assumptions require manual adaptation. Use the command job
as the reproducible student path.

For serving, set a globally unique endpoint name. The deployment uses the model
version returned above. From the collection root:

```powershell
$ENDPOINT = 'YOUR_GLOBALLY_UNIQUE_ENDPOINT_NAME'
az ml online-endpoint create -f .\09-IMDB-Sentiment-Classification\deploy\endpoint.yml `
  --set name=$ENDPOINT -g $RG -w $WS
az ml online-deployment create -f .\09-IMDB-Sentiment-Classification\deploy\deployment.yml `
  --set endpoint_name=$ENDPOINT model=azureml:course-imdb-sentiment-model:$MODEL_VERSION `
  -g $RG -w $WS
az ml online-endpoint update -n $ENDPOINT --traffic blue=100 `
  -g $RG -w $WS
az ml online-endpoint invoke -n $ENDPOINT `
  --request-file .\09-IMDB-Sentiment-Classification\deploy\sample-request.json `
  -g $RG -w $WS
az ml online-endpoint delete -n $ENDPOINT --yes `
  -g $RG -w $WS
```

The explicit scoring script and inference environment passed a live East US
deployment and sample invocation on 11 November 2026. The sample returned one
positive and one negative prediction. The custom image build took several
minutes. See the standalone validation report in the repository root.

## Next exercise

Confirm the IMDB endpoint has been deleted, but keep the Azure ML workspace and
`course-cpu`. Continue with
[Exercise 10](../../10-Delhi-Climate-Time-Series/Instruction/README.md), which
registers its own climate data assets and model in the same workspace.
