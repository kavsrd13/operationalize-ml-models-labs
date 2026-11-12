# Exercise 04: Train through an Azure ML pipeline

## Goal

Prepare order-level checkout features in one step, pass them to a training step,
and inspect the model produced by the pipeline.

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

- [`delivery-time-local.ipynb`](../delivery-time-local.ipynb)
- [`src/prep/prep.py`](../src/prep/prep.py)
- [`src/train/train.py`](../src/train/train.py)
- [`pipelines/delivery-time-pipeline.yml`](../pipelines/delivery-time-pipeline.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Use the `$RG` and `$WS` values from the Azure setup section above. Confirm
   `olist-ecommerce-raw:1` and `course-cpu` exist.
2. Open `../delivery-time-local.ipynb` with the Olist kernel. Run every cell and
   identify which fields are known at checkout.
3. Read `../src/prep/prep.py` and `../src/train/train.py`. Trace the feature
   folder from preparation into training.
4. Read `../pipelines/delivery-time-pipeline.yml`. Find its raw input,
   default compute, `prep` output, `train` input, and `trained_model` output.
5. Preview and submit the pipeline from the collection root:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\submit.py delivery --dry-run
   python .\00-Shared-Setup-and-Data\scripts\submit.py delivery
   ```

6. Copy the pipeline job name, then run the status command every few minutes
   until it says `Completed`:

   ```powershell
   az ml job show -n YOUR_PIPELINE_JOB -g $RG -w $WS --query status -o tsv
   ```

   Streaming is optional because some Azure CLI versions fail with `Incorrect
   padding` even when the Azure job succeeds.

7. In Studio inspect both child jobs, their logs, metrics, and `trained_model`.
   Explain why `train` cannot start before `prep` finishes.

The `../extended-demo/` folder is supplemental source material with older paths.

## Next exercise

Keep the same workspace, raw data asset, and `course-cpu` cluster. Continue with
[Exercise 05](../../05-Freight-AutoML-and-MLflow/Instruction/README.md). Do not
delete the resource group or rerun shared setup.
