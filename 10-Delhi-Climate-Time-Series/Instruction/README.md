# Exercise 10: Delhi climate time-series regression

## Goal

Create lag-based climate features, train and track a forecasting model locally, then
register, deploy, and invoke it through Azure ML.

## Local route

1. Open `../train_delhi_climate_timeseries_local.ipynb`.
2. Start/configure MLflow.
3. Load the train and test CSVs, create lag-one features, train, and inspect metrics.

## Azure route

Use the same Azure ML workspace and `olist-course-cpu` cluster as exercises 03–09.
From the collection root, register the two CSVs once as named assets, then
submit the command job. It creates lag-one features and logs test MAE/RMSE.

```powershell
az ml data create -f .\10-Delhi-Climate-Time-Series\data\train.yml `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml data create -f .\10-Delhi-Climate-Time-Series\data\test.yml `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml data show -n course-delhi-train -v 1 -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml data show -n course-delhi-test -v 1 -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml job create --file .\10-Delhi-Climate-Time-Series\jobs\train.yml `
  --resource-group YOUR_RESOURCE_GROUP --workspace-name YOUR_WORKSPACE
```

Use `az ml job stream -n YOUR_COMPLETED_JOB -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE`
and wait for `Completed`. Inspect metrics and `outputs/model`, then register it as a
new version of `course-delhi-climate-model`:

```powershell
az ml model create -n course-delhi-climate-model --type mlflow_model `
  --path "azureml://jobs/YOUR_COMPLETED_JOB/outputs/artifacts/paths/outputs/model/" `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
```

The older interactive Azure notebook
assumes a pre-existing folder data asset and nearby `config.json`; use the command job
for the reproducible student path.

For serving, replace the endpoint name and model version below with values from your
workspace. From the collection root:

```powershell
az ml online-endpoint create -f .\10-Delhi-Climate-Time-Series\deploy\endpoint.yml `
  --set name=YOUR_UNIQUE_ENDPOINT -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-deployment create -f .\10-Delhi-Climate-Time-Series\deploy\deployment.yml `
  --set endpoint_name=YOUR_UNIQUE_ENDPOINT model=azureml:course-delhi-climate-model:YOUR_MODEL_VERSION `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint update -n YOUR_UNIQUE_ENDPOINT --traffic blue=100 `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint invoke -n YOUR_UNIQUE_ENDPOINT `
  --request-file .\10-Delhi-Climate-Time-Series\deploy\sample-request.json `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint delete -n YOUR_UNIQUE_ENDPOINT --yes `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
```

Endpoint creation succeeded in a temporary East US workspace, but Azure's generated
MLflow scoring image failed its health checks. This folder now supplies an explicit
scoring script and inference environment; their live deployment and invocation remain
unverified. See the endpoint validation report before teaching this serving step.
