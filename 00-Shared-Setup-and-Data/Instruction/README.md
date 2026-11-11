# Exercise 00: One shared Azure ML setup

## Goal

Use one workspace, one scale-to-zero CPU cluster, and named data assets throughout
the course. Exercises 01 and 02 run locally; cloud exercises 03–11 reuse this setup.

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

- [`scripts/bootstrap.py`](../scripts/bootstrap.py)
- [`scripts/compute.yml`](../scripts/compute.yml)
- [`scripts/requirements.txt`](../scripts/requirements.txt)
- [`datasets/olist/olist-data-asset.yml`](../../datasets/olist/olist-data-asset.yml)
- [`azure-ml-infra/infra/main.bicep`](../azure-ml-infra/infra/main.bicep)
- [`azure-ml-infra/README.md`](../azure-ml-infra/README.md)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Steps

1. Check `python --version` and `az version`. The commands above clone the
   code, create or reuse the resource group and workspace, extract Olist data,
   install the notebook kernel, register `olist-ecommerce-raw:1`, and create
   `course-cpu` only if absent.
2. Check the reusable resources:

   ```powershell
   az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS --query name -o tsv
   az ml compute show -n course-cpu -g $RG -w $WS `
     --query '{name:name,min:min_instances,max:max_instances}' -o json
   ```

3. Open a local notebook, select **Python (Olist Azure ML)**, and run its first
   import and data-loading cells. Labs 01 and 02 submit no cloud jobs.
4. On a second machine, clone the materials and rerun the setup with the **same**
   subscription, group, and workspace. Existing assets are checked and reused.

## Naming map

| Resource | Name | Reused by |
| --- | --- | --- |
| Azure ML workspace | `$WS`, created or reused above | 03–11 |
| CPU training cluster | `course-cpu` | 03–07, 09–11 |
| Olist raw data asset | `olist-ecommerce-raw:1` | 03–07, 11 |
| Freight prepared assets | `olist-freight-*` | 05 |
| Late-delivery prepared assets | `olist-late-*` | 06–07 |
| IMDB/Delhi assets | `course-imdb-data:1`, `course-delhi-*` | 09–10 |

Managed online endpoints have their own serving compute; the training cluster
cannot host them. Endpoint names must be globally unique. Do not commit
`config.json`, credentials, endpoint keys, or `.venv`.
