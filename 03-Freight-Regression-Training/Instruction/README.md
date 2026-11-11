# Exercise 03: Train a freight regression model

## Goal

Predict item freight cost from checkout-time features, compare a median baseline,
Ridge, and gradient boosting, and inspect the MLflow model created by Azure ML.

## Steps

1. Complete exercise 00. At the collection root in PowerShell set
   `$RG = 'YOUR_RESOURCE_GROUP'` and `$WS = 'YOUR_WORKSPACE'`.
2. Confirm the shared resources:

   ```powershell
   az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS --query name -o tsv
   az ml compute show -n olist-course-cpu -g $RG -w $WS --query name -o tsv
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

8. In Studio compare MAE against the median baseline, inspect the prediction
   plot and `outputs/model`, and identify the held-out time period. The model
   output is used by exercise 08.

The `../extended-demo/` folder is supplemental source material with older paths.
