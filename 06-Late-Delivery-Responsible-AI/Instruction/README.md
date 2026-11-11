# Exercise 06: Late delivery and Responsible AI

## Goal

Train a late-delivery classifier, register its model, and inspect cohort errors,
feature explanations, and the Responsible AI dashboard.

## Steps

1. Complete exercise 00. In PowerShell at the collection root set `$RG` and
   `$WS` to your shared resource group and workspace. Confirm
   `olist-course-cpu` exists.
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
   az ml job create -f .\06-Late-Delivery-Responsible-AI\jobs\train.yml -g $RG -w $WS
   az ml job stream -n YOUR_TRAIN_JOB -g $RG -w $WS
   ```

6. In Studio inspect the full future-period classification metrics. When the
   job is `Completed`, register its MLflow output:

   ```powershell
   az ml model create -n olist-late-delivery-rai --type mlflow_model `
     --path 'azureml://jobs/YOUR_TRAIN_JOB/outputs/artifacts/paths/outputs/model/' `
     -g $RG -w $WS
   ```

7. Check the returned model version. `../jobs/rai-dashboard.yml` references
   version 1; if yours differs, change its `selected_model.path` and
   `construct.inputs.model_info` to the version you just registered.
8. Read `../lab-guide.html` for the dashboard's component flow, then submit:

   ```powershell
   az ml job create -f .\06-Late-Delivery-Responsible-AI\jobs\rai-dashboard.yml -g $RG -w $WS
   az ml job stream -n YOUR_DASHBOARD_JOB -g $RG -w $WS
   ```

9. Open the dashboard in Studio. Compare error and explanation views across
   cohorts. Observed differences alone do not establish causality or a
   fairness violation.
