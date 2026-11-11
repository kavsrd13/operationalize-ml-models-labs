# Exercise 07: Tune late-delivery classification

## Goal

Tune logistic regression on pre-April training and April–May validation data.
Keep June–August test labels out of selection.

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

- [`Azure ML late delivery sweep.ipynb`](../Azure%20ML%20late%20delivery%20sweep.ipynb)
- [`prepare.py`](../prepare.py)
- [`src/sweep_train.py`](../src/sweep_train.py)
- [`jobs/sweep-smoke.yml`](../jobs/sweep-smoke.yml)
- [`jobs/sweep.yml`](../jobs/sweep.yml)
- [`environment/environment.yml`](../environment/environment.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Confirm the setup above created `course-cpu`. Open
   `../Azure ML late delivery sweep.ipynb` with the Olist kernel.
2. In notebook step 1 leave `REGISTER_RESOURCES` and `SUBMIT_SWEEP` at
   `False`. Run preparation and inspect the generated train/validation
   `MLTable` and Parquet files.
3. Set `REGISTER_RESOURCES = True` and rerun the registration cell. Verify
   `olist-late-sweep-train:1`, `olist-late-sweep-validation:1`, and
   `olist-sweep-env:2` in the shared workspace.
4. Read `../jobs/sweep-smoke.yml`, `../jobs/sweep.yml`, and the trial script.
   The smoke job uses fixed values; the full sweep has at most eight trials,
   one concurrent trial, and a 300-minute limit.
5. From the collection root, run the smoke job and wait for `Completed`:

   ```powershell
   az ml job create -f .\07-Late-Delivery-Hyperparameter-Sweep\jobs\sweep-smoke.yml `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   az ml job stream -n YOUR_SMOKE_JOB -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   ```

6. Set `SUBMIT_SWEEP = True` in notebook step 1 and run the sweep submission
   cell once. The job name is saved in ignored `.sweep-run-id.json` to avoid
   duplicate submissions. Alternatively submit `../jobs/sweep.yml` with
   `az ml job create -f` using the same group and workspace.
7. In Studio inspect average precision and late-class precision/recall for
   every trial. Record the selected settings and explain why validation
   results are not a final future-period test.
8. Reset the notebook submission flags to `False` after the run.
