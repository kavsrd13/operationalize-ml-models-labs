# Exercise 08: Online model serving

## Goal

Deploy the freight model to a managed online endpoint, validate requests, invoke the
endpoint, and test a small Gradio client.

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

- [`src/train.py`](../src/train.py)
- [`jobs/train-job.yml`](../jobs/train-job.yml)
- [`deploy/score.py`](../deploy/score.py)
- [`deploy/endpoint.yml`](../deploy/endpoint.yml)
- [`deploy/deployment.yml`](../deploy/deployment.yml)
- [`deploy/conda.yaml`](../deploy/conda.yaml)
- [`deploy/sample-request.json`](../deploy/sample-request.json)
- [`deploy/sample-invalid-request.json`](../deploy/sample-invalid-request.json)
- [`app/app.py`](../app/app.py)
- [`app/requirements.txt`](../app/requirements.txt)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Run

1. Open this lab's `src/train.py` and `jobs/train-job.yml`. The command job trains
   a freight model from the raw asset created above. Submit it, then wait for
   `Completed` before registering its `outputs/model` folder. This lab does not
   require a run from exercise 03.

   ```powershell
   $TRAIN_JOB = az ml job create -f .\08-Online-Model-Serving\jobs\train-job.yml `
     -g $RG -w $WS --query name -o tsv
   az ml job show -n $TRAIN_JOB -g $RG -w $WS --query status -o tsv
   ```

   Repeat the status command until it says `Completed`. In Studio, check MAE
   against the median baseline and inspect the model output. Register that
   specific job's model:

   ```powershell
   $MODEL_VERSION = az ml model create -n olist-freight-cost --type mlflow_model `
     --path "azureml://jobs/$TRAIN_JOB/outputs/artifacts/paths/outputs/model/" `
     -g $RG -w $WS --query version -o tsv
   Write-Host "Registered model version $MODEL_VERSION"
   ```
2. Pick a globally unique endpoint name and set the variable before running
   the deployment commands. The checked-in YAML names are placeholders.

   ```powershell
   $ENDPOINT = 'YOUR_GLOBALLY_UNIQUE_ENDPOINT_NAME'
   ```
3. Review the inference VM size and quota. From the collection root, create and test:

   ```powershell
   az ml online-endpoint create --file .\08-Online-Model-Serving\deploy\endpoint.yml `
     --set name=$ENDPOINT -g $RG -w $WS
   az ml online-deployment create --file .\08-Online-Model-Serving\deploy\deployment.yml `
     --set endpoint_name=$ENDPOINT model=azureml:olist-freight-cost:$MODEL_VERSION `
     -g $RG -w $WS
   az ml online-endpoint update -n $ENDPOINT --traffic blue=100 `
     -g $RG -w $WS
   az ml online-endpoint invoke -n $ENDPOINT `
     --request-file .\08-Online-Model-Serving\deploy\sample-request.json `
     -g $RG -w $WS
   ```

4. Invoke `../deploy/sample-invalid-request.json` with the same endpoint command;
   verify that scoring reports a useful validation error.

   ```powershell
   az ml online-endpoint invoke -n $ENDPOINT `
     --request-file .\08-Online-Model-Serving\deploy\sample-invalid-request.json `
     -g $RG -w $WS
   ```
5. In `../app/.env`, set `FREIGHT_ENDPOINT_URL` from
   `az ml online-endpoint show -n $ENDPOINT --query scoring_uri` and
   `FREIGHT_ENDPOINT_KEY` from
   `az ml online-endpoint get-credentials -n $ENDPOINT --query primaryKey`.
   Keep this file untracked. Install `../app/requirements.txt`, run
   `python .\08-Online-Model-Serving\app\app.py`, and submit sample fields.
6. Delete only your own endpoint immediately after the demo:

   ```powershell
   az ml online-endpoint delete -n $ENDPOINT --yes `
     -g $RG -w $WS
   ```

## Next exercise

Confirm the endpoint deletion finishes, but keep the Azure ML workspace,
`olist-ecommerce-raw:1`, and `course-cpu`. Continue with
[Exercise 09](../../09-IMDB-Sentiment-Classification/Instruction/README.md).
Exercise 09 creates its own data asset and model in the same workspace.

Never copy endpoint keys into source files or instructional screenshots.

The freight endpoint, sample invocation, and malformed-request check completed in a
temporary East US workspace on 11 November 2026. This exercise's own training
job and model registration completed in West US. A new West US endpoint attempt
failed with a subscription registration error; the temporary endpoint was
removed. See the endpoint and standalone validation reports in the repository root.
