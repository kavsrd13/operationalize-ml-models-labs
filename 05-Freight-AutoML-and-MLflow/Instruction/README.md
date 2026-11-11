# Exercise 05: Compare AutoML and MLflow experiments

## Goal

Prepare chronological freight data, compare bounded AutoML with tracked Ridge
and boosting jobs, select on validation data, and use the held-out test once.

## Start from a fresh clone

Ask the instructor for access to the private GitHub repository. Install Python 3.10 or 3.11, GitHub CLI, Azure CLI, and a notebook editor. From an empty working folder in PowerShell:

```powershell
gh auth login
gh repo clone kavsrd13/operationalize-ml-models-labs
Set-Location .\operationalize-ml-models-labs
```

Set your own subscription, resource group, workspace, and region. The commands create the group and workspace if needed, install the shared Olist asset, and create one scale-to-zero training cluster named `course-cpu`. Reuse the same names in later labs. Check regional quota for `Standard_E4ds_v4`.

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

- [`Olist freight Azure ML experiments.ipynb`](../Olist%20freight%20Azure%20ML%20experiments.ipynb)
- [`prepare.py`](../prepare.py)
- [`train.py`](../src/train.py)
- [`evaluate.py`](../src/evaluate.py)
- [`automl-regression.yml`](../jobs/automl-regression.yml)
- [`track-mlflow.yml`](../jobs/track-mlflow.yml)
- [`evaluate.yml`](../jobs/evaluate.yml)
- [`train.yml`](../data/train.yml)
- [`validation.yml`](../data/validation.yml)
- [`test.yml`](../data/test.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Confirm the setup above created `course-cpu`. Open
   `../Olist freight Azure ML experiments.ipynb` with **Python (Olist Azure ML)**.
2. In notebook step 1 leave `UPLOAD_DATA`, `SUBMIT_JOBS`, and
   `SUBMIT_EVALUATION` set to `False`. Run the setup and preparation cells.
3. Inspect the three `data/{train,validation,test}` folders. Each must have
   `orders.csv` and `MLTable`; dates must be chronological. The test set is
   reserved until a validation winner is chosen.
4. Set `UPLOAD_DATA = True` and rerun the registration cell. Verify the named
   assets `olist-freight-train:1`, `olist-freight-validation:1`, and
   `olist-freight-test:1` in Studio. Existing version 1 assets are reused.
5. Review `../jobs/automl-regression.yml` (five trials, one concurrent,
   90-minute total), `../jobs/track-mlflow.yml`, and `../src/train.py`.
   All jobs use `course-cpu`.
6. Set `SUBMIT_JOBS = True`, rerun notebook steps 6–8, and record the AutoML,
   Ridge, and boosting job IDs saved in ignored `.freight-run-ids.json`.
7. Wait until all three jobs show `Completed`. In Studio inspect validation
   MAE, baseline, plots, MLflow parameters, and model outputs. Choose either
   Ridge or boosting using validation evidence; do not choose on test data.
8. In the notebook's final evaluation cell set `selected_algorithm` to the
   chosen manual model and `SUBMIT_EVALUATION = True`. This registers the
   selected model and submits `../jobs/evaluate.yml` against
   `olist-freight-test:1` once.
9. Wait for the evaluation job to complete. Record held-out MAE/RMSE and
   compare them to validation. If the test result differs, discuss time drift.
10. Reset the three submission flags to `False` in your saved notebook.

Do not delete the shared cluster or assets while later exercises need them.
