# Exercise 00: Set up Python and shared data

## What you will do

Set up the local Python environment and unpack the shared Olist dataset. You do
not need Azure for exercises 01 and 02. Set up Azure only when you are ready to
start a cloud exercise.

## 1. Install the basics

Install Python 3.10 or 3.11 and Git. If you use VS Code, install its **Python**
and **Jupyter** extensions. Azure CLI is only needed for the cloud setup below.

## 2. Clone the course

You can clone the public repository without signing in:

```powershell
git clone https://github.com/kavsrd13/operationalize-ml-models-labs.git
Set-Location .\operationalize-ml-models-labs
```

To keep your own changes in GitHub, fork the repository first and clone your
fork instead. Forking and pushing require a GitHub account; cloning does not.

## 3. Set up locally

Run this once from the repository root:

```powershell
python --version
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
```

Bootstrap extracts the nine Olist CSVs, creates `.venv`, installs the packages
listed in [`scripts/requirements.txt`](../scripts/requirements.txt), and registers
the **Python (Olist Azure ML)** notebook kernel. No separate `pip install` is
needed.

Check that the data can be read:

```powershell
.\.venv\Scripts\python.exe -c "from pathlib import Path; import pandas as pd; d=Path('datasets/olist/Ecommerce Dataset'); print('CSV files:', len(list(d.glob('*.csv')))); print('Orders:', pd.read_csv(d/'olist_orders_dataset.csv').shape)"
```

The expected output starts with `CSV files: 9` and `Orders: (99441, 8)`.
In VS Code, open a notebook and select **Python (Olist Azure ML)**. Exercises
01 and 02 now run locally and do not submit Azure jobs.

## 4. Set up Azure when you need a cloud exercise

Skip this section until you start exercises 03–11. You need an Azure
subscription with permission to create a resource group, workspace, and compute.
The shared cluster uses `Standard_E4ds_v4`; check that your chosen region has
quota for it. Cloud resources can incur charges while they are running.

Install Azure CLI, sign in, and select your subscription:

```powershell
$SUB = 'YOUR_SUBSCRIPTION_ID'
$RG = 'rg-course-ml'
$WS = 'mlw-course-ml'
$LOCATION = 'eastus'
az login
az account set --subscription $SUB
az extension add --name ml --yes
az group create --name $RG --location $LOCATION
```

If you do not already have a workspace, create one:

```powershell
az ml workspace create --name $WS --resource-group $RG --location $LOCATION --subscription $SUB
```

Then register the shared data asset and create the reusable, scale-to-zero
training cluster:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py `
  --subscription $SUB --resource-group $RG --workspace $WS --create-cluster
```

Bootstrap checks for existing resources and reuses them. Keep the same
subscription, resource group, and workspace for later cloud exercises.

## Optional: Bicep infrastructure exercise

[`azure-ml-infra/README.md`](../azure-ml-infra/README.md) is a separate, advanced
exercise for learning Azure infrastructure as code. It is not required for the
numbered course labs. Follow either its deployment workflow or the shared
workspace setup above; do not deploy both unless you intentionally want separate
Azure resources.

## Shared resources

| Resource | Reused by |
| --- | --- |
| `olist-ecommerce-raw:1` data asset | 03–08 |
| `course-cpu` training cluster | 03–10 |
| Prepared data assets | Created in the labs that need them |

Managed online endpoints use separate serving compute. Do not commit
`config.json`, credentials, endpoint keys, or `.venv`.

## Course resource lifecycle

Create the Azure ML workspace, `course-cpu`, and `olist-ecommerce-raw:1` once
when you begin Exercise 03. Keep them while you work through Exercises 04–10;
each guide ends with a **Next exercise** section telling you exactly what to
retain. Managed online endpoints in Exercises 08–10 are deleted immediately
after their individual demos. Exercise 10 contains the final command that
deletes the shared course resource group and verifies that deletion completed.
