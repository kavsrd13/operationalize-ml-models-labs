# Exercise 09: IMDB sentiment classification

## Goal

Train and track a text sentiment classifier locally, then repeat the lifecycle with an
Azure ML data asset, model registration, managed deployment, and invocation.

## Local route

1. Open `../train_imdb_sentiment_local.ipynb`.
2. Start the local MLflow server as instructed.
3. Load `../IMDB Dataset.csv`, train the classifier, and inspect logged results.

## Azure route

Use the same Azure ML workspace and `olist-course-cpu` cluster as exercises 03–08.
From the collection root, register the CSV once as a named asset, then submit
the command job. The `../src/train.py` source has the
same TF-IDF and logistic regression flow as the local notebook.

```powershell
az ml data create --file .\09-IMDB-Sentiment-Classification\data\imdb.yml `
  --resource-group YOUR_RESOURCE_GROUP --workspace-name YOUR_WORKSPACE
az ml data show -n course-imdb-data -v 1 -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml job create --file .\09-IMDB-Sentiment-Classification\jobs\train.yml `
  --resource-group YOUR_RESOURCE_GROUP --workspace-name YOUR_WORKSPACE
```

Use `az ml job stream -n YOUR_COMPLETED_JOB -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE`
and wait for `Completed`. Inspect `test_accuracy` and `outputs/model`, then register
that artifact as a new version of `course-imdb-sentiment-model` before deployment:

```powershell
az ml model create -n course-imdb-sentiment-model --type mlflow_model `
  --path "azureml://jobs/YOUR_COMPLETED_JOB/outputs/artifacts/paths/outputs/model/" `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
```
The older `../train_imdb_sentiment_azureml.ipynb` shows an interactive route, but its
asset and workspace setup assumptions require manual adaptation. Use the command job
as the reproducible student path.

For serving, replace the endpoint name and model version below with values from your
workspace. From the collection root:

```powershell
az ml online-endpoint create -f .\09-IMDB-Sentiment-Classification\deploy\endpoint.yml `
  --set name=YOUR_UNIQUE_ENDPOINT -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-deployment create -f .\09-IMDB-Sentiment-Classification\deploy\deployment.yml `
  --set endpoint_name=YOUR_UNIQUE_ENDPOINT model=azureml:course-imdb-sentiment-model:YOUR_MODEL_VERSION `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint update -n YOUR_UNIQUE_ENDPOINT --traffic blue=100 `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint invoke -n YOUR_UNIQUE_ENDPOINT `
  --request-file .\09-IMDB-Sentiment-Classification\deploy\sample-request.json `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
az ml online-endpoint delete -n YOUR_UNIQUE_ENDPOINT --yes `
  -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
```

Endpoint creation succeeded in a temporary East US workspace, but Azure's generated
MLflow scoring image failed its health checks. This folder now supplies an explicit
scoring script and inference environment; their live deployment and invocation remain
unverified. See the endpoint validation report before teaching this serving step.
