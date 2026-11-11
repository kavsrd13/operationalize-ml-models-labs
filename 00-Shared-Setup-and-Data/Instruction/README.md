# Exercise 00: One shared Azure ML setup

## Goal

Use one workspace, one scale-to-zero CPU cluster, and named data assets throughout
the course. Exercises 01 and 02 run locally; cloud exercises 03–11 reuse this setup.

## Steps

1. Install Python 3.10 or 3.11, Azure CLI, the Azure ML CLI v2 extension, and a
   notebook editor. Check `python --version` and `az version`.
2. Open PowerShell in the **Streamlined Exercises** folder. Sign in and select
   the subscription that contains your existing Azure ML workspace:

   ```powershell
   az login
   az extension add --name ml --yes
   $SUB = 'YOUR_SUBSCRIPTION_ID'
   $RG = 'YOUR_RESOURCE_GROUP'
   $WS = 'YOUR_WORKSPACE'
   az account set --subscription $SUB
   az ml workspace show -n $WS -g $RG --subscription $SUB --query name -o tsv
   ```

3. Check regional quota for `Standard_E4ds_v4` and cost. The cluster has
   minimum zero, maximum one. If the workspace must be created, follow
   `../azure-ml-infra/README.md` and return here with its names.
4. Run the setup once. It extracts Olist CSVs, installs the notebook kernel,
   writes ignored `config.json`, registers `olist-ecommerce-raw:1`, and creates
   `olist-course-cpu` only if absent:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\bootstrap.py `
     --subscription $SUB --resource-group $RG --workspace $WS --create-cluster
   ```

5. Check the reusable resources:

   ```powershell
   az ml data show -n olist-ecommerce-raw -v 1 -g $RG -w $WS --query name -o tsv
   az ml compute show -n olist-course-cpu -g $RG -w $WS `
     --query '{name:name,min:min_instances,max:max_instances}' -o json
   ```

6. Open a local notebook, select **Python (Olist Azure ML)**, and run its first
   import and data-loading cells. Labs 01 and 02 submit no cloud jobs.
7. On a second machine, clone the materials and rerun the setup with the **same**
   subscription, group, and workspace. Existing assets are checked and reused.

## Naming map

| Resource | Name | Reused by |
| --- | --- | --- |
| Azure ML workspace | Your existing `$WS` | 03–11 |
| CPU training cluster | `olist-course-cpu` | 03–07, 09–11 |
| Olist raw data asset | `olist-ecommerce-raw:1` | 03–07, 11 |
| Freight prepared assets | `olist-freight-*` | 05 |
| Late-delivery prepared assets | `olist-late-*` | 06–07 |
| IMDB/Delhi assets | `course-imdb-data:1`, `course-delhi-*` | 09–10 |

Managed online endpoints have their own serving compute; the training cluster
cannot host them. Endpoint names must be globally unique. Do not commit
`config.json`, credentials, endpoint keys, or `.venv`.
