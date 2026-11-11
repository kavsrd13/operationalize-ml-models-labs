# Exercise 08: Online model serving

## Goal

Deploy the freight model to a managed online endpoint, validate requests, invoke the
endpoint, and test a small Gradio client.

## Run

1. Wait for exercise 03's job status to become `Completed`. Register that job's
   `outputs/model` folder as an MLflow model. Use its returned version, not a version
   number copied from another workspace.

   ```powershell
   az ml model create -n olist-freight-cost --type mlflow_model `
     --path 'azureml://jobs/YOUR_TRAIN_JOB/outputs/artifacts/paths/outputs/model/' `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   ```
2. Pick one globally unique endpoint name and use it in **both** endpoint and
   deployment definitions. The checked-in YAML names are placeholders.
3. Review the inference VM size and quota. From the collection root, create and test:

   ```powershell
   az ml online-endpoint create --file .\08-Online-Model-Serving\deploy\endpoint.yml `
     --set name=YOUR_UNIQUE_ENDPOINT -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   az ml online-deployment create --file .\08-Online-Model-Serving\deploy\deployment.yml `
     --set endpoint_name=YOUR_UNIQUE_ENDPOINT model=azureml:olist-freight-cost:YOUR_MODEL_VERSION `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   az ml online-endpoint update -n YOUR_UNIQUE_ENDPOINT --traffic blue=100 `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   az ml online-endpoint invoke -n YOUR_UNIQUE_ENDPOINT `
     --request-file .\08-Online-Model-Serving\deploy\sample-request.json `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   ```

4. Invoke `../deploy/sample-invalid-request.json` with the same endpoint command;
   verify that scoring reports a useful validation error.
5. In `../app/.env`, set `FREIGHT_ENDPOINT_URL` from
   `az ml online-endpoint show -n YOUR_UNIQUE_ENDPOINT --query scoring_uri` and
   `FREIGHT_ENDPOINT_KEY` from
   `az ml online-endpoint get-credentials -n YOUR_UNIQUE_ENDPOINT --query primaryKey`.
   Keep this file untracked. Install `../app/requirements.txt`, run
   `python .\08-Online-Model-Serving\app\app.py`, and submit sample fields.
6. Delete only your own endpoint immediately after the demo:

   ```powershell
   az ml online-endpoint delete -n YOUR_UNIQUE_ENDPOINT --yes `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   ```

Never copy endpoint keys into source files or instructional screenshots.

The freight endpoint, sample invocation, and malformed-request check completed in a
temporary East US workspace on 11 November 2026. See the endpoint validation report.
