# Module 1 — Azure Machine Learning Infrastructure as Code (Bicep)

> **Optional advanced exercise:** the numbered course labs use the shared setup
> in [`00-Shared-Setup-and-Data/Instruction`](../Instruction/README.md). Follow
> this Bicep workflow only if you want to learn infrastructure as code; deploying
> both workflows can create separate Azure resources.
>
> **Students:** open **[lab-guide.html](lab-guide.html)** in your browser for the step-by-step exercise.
> This README is the full reference.

This module builds the cloud environment for the **Olist e-commerce ML course** entirely
from code. You don't click through the Azure portal. A Bicep template creates everything,
and you can review it, version it in git and redeploy it.

After the module you will have:

- An **Azure Machine Learning workspace**, with all the resources it depends on
- A personal **compute instance** (a cloud Jupyter / VS Code workstation)
- The 9 **Olist CSV files** uploaded and registered as a versioned **data asset**

---

## Contents

1. [What you will build](#1-what-you-will-build)
2. [Why Bicep?](#2-why-bicep)
3. [Folder structure](#3-folder-structure)
4. [Prerequisites](#4-prerequisites)
5. [Quick start](#5-quick-start)
6. [Step-by-step lab](#6-step-by-step-lab)
7. [How the Bicep code works](#7-how-the-bicep-code-works)
8. [Why the data upload is a separate step](#8-why-the-data-upload-is-a-separate-step)
9. [Configuration reference](#9-configuration-reference)
10. [Cost control and cleanup](#10-cost-control-and-cleanup)
11. [Troubleshooting](#11-troubleshooting)
12. [CI/CD with GitHub Actions (advanced)](#12-cicd-with-github-actions-advanced)
13. [Design decisions](#13-design-decisions)
14. [Exercises](#14-exercises)
15. [References](#15-references)

---

## 1. What you will build

```
Subscription
└── Resource group  rg-olist-ml-dev
    │
    ├── Log Analytics workspace   log-olist-dev        ─┐  monitoring
    ├── Application Insights      appi-olist-dev       ─┘  (job + endpoint telemetry)
    │
    ├── Storage account           stolistdev<suffix>   ←  data, job outputs, notebooks
    ├── Key Vault                 kv-olist-dev-<suffix> ← secrets
    ├── Container Registry        crolistdev<suffix>   ←  Docker images for environments
    │
    └── Azure ML workspace        mlw-olist-dev        ←  the "hub" that links all of the above
        ├── Compute instance      ci-olist-dev<suffix> ←  your personal workstation
        └── Data asset            olist-ecommerce-raw:1  (9 CSV files, ~126 MB)

    + Role assignments for the data scientist (least privilege)
```

| Resource | Why the workspace needs it | Required? |
|---|---|---|
| Storage account | Default datastores: `workspaceblobstore` (data) and `workspacefilestore` (notebooks) | Yes |
| Key Vault | Stores secrets such as datastore keys and connection strings | Yes |
| Application Insights + Log Analytics | Monitoring of jobs and deployed models | Yes |
| Container Registry | Images for custom environments and model deployments | Optional, but created here so nothing gets auto-created outside your code |
| Compute instance | Personal dev box with Jupyter, VS Code and the Azure ML SDK | Optional |

---

## 2. Why Bicep?

Microsoft supports several infrastructure-as-code (IaC) tools for Azure. This course uses
**Bicep**, which is Microsoft's own language for Azure-native deployments.

| Tool | What it is | When Microsoft suggests it |
|---|---|---|
| **Bicep** ✅ | Azure's native IaC language; compiles to ARM JSON | The default for Azure-only work. New resource types and API versions are available on day one, there is no state file to manage, and it is covered by Microsoft support. |
| ARM JSON | The underlying template format | Microsoft recommends Bicep instead for anyone new to IaC. |
| Terraform | HashiCorp's multi-cloud IaC tool | Multi-cloud or hybrid estates. It needs a state file. |
| Azure Developer CLI (`azd`) | Workflow tool for whole applications | Wraps Bicep (its default) for app templates and dev loops. |

> The same environment could be written in Terraform (`azurerm_machine_learning_workspace`,
> `azurerm_machine_learning_compute_instance`). Bicep needs no state file, which makes it the
> simplest start for a course.

---

## 3. Folder structure

```
azure-ml-infra/
├── README.md                         ← you are here
├── infra/                            ← INFRASTRUCTURE (Bicep)
│   ├── main.bicep                    ← entry point (subscription scope): resource group + modules
│   ├── main.bicepparam               ← parameter values (overridable by environment variables)
│   ├── bicepconfig.json              ← linter rules (best-practice checks)
│   └── modules/
│       ├── monitoring.bicep          ← Log Analytics + Application Insights
│       ├── storage-account.bicep     ← default storage for the workspace
│       ├── key-vault.bicep           ← secrets (RBAC authorization)
│       ├── container-registry.bicep  ← Docker image registry
│       ├── ml-workspace.bicep        ← the Azure ML workspace
│       ├── compute-instance.bicep    ← personal compute instance
│       └── role-assignments.bicep    ← least-privilege access for the data scientist
├── data/
│   └── olist-data-asset.yml          ← Azure ML data asset definition (CLI v2 YAML)
├── scripts/                          ← AUTOMATION (PowerShell 5.1 / 7+)
│   ├── common.ps1                    ← shared helpers + naming convention
│   ├── 00-check-prerequisites.ps1    ← tools, login, providers, permissions, quota
│   ├── 01-validate-infra.ps1         ← lint → build → preflight → what-if (creates nothing)
│   ├── 02-deploy-infra.ps1           ← deploys the Bicep template, saves outputs
│   ├── 03-upload-data.ps1            ← uploads the CSVs + registers the data asset
│   ├── 04-verify-deployment.ps1      ← checks every component
│   ├── 99-cleanup.ps1                ← deletes everything, including soft-deleted leftovers
│   └── deploy-all.ps1                ← runs 00 → 04 in one go
└── .github/workflows/
    └── deploy-azureml-infra.yml      ← optional CI/CD pipeline (OIDC, what-if on PR)
```

Before uploading, extract the bundled data once from the collection root:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-install --skip-azure
```

The upload script reads `datasets\olist\Ecommerce Dataset` by default. Pass
`-SourceFolder` only if you keep the extracted CSVs somewhere else.

---

## 4. Prerequisites

| Requirement | How to check / get it |
|---|---|
| Azure subscription | Free, student, MSDN or pay-as-you-go |
| Role on the subscription | **Owner**, or **Contributor + Role Based Access Control Administrator**. The template creates role assignments, which Contributor alone can't do. |
| Azure CLI **2.61+** | `az version`. Install with `winget install -e --id Microsoft.AzureCLI` |
| Bicep CLI | Bundled with Azure CLI: `az bicep install` / `az bicep upgrade` |
| Azure ML CLI v2 extension | `az extension add -n ml`. `00-check-prerequisites.ps1` installs it for you. |
| PowerShell | Windows PowerShell 5.1 or PowerShell 7+ (macOS and Linux work too) |
| VM quota | At least 4 vCPUs in the compute instance's VM family. The prerequisites script checks this. |

**No passwords or keys are needed.** Every script uses your `az login` session, and every
service uses managed identities.

```powershell
az login                                    # opens the browser
az account set --subscription "<name-or-id>"
```

> **Execution policy.** If Windows blocks the scripts, allow them for the current session
> only: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. Files synced from
> OneDrive or downloaded may also need `Get-ChildItem -Recurse | Unblock-File`.

---

## 5. Quick start

Run these from the `azure-ml-infra` folder:

```powershell
.\scripts\deploy-all.ps1                                   # defaults: olist / dev / eastus
# or
.\scripts\deploy-all.ps1 -ProjectName olistanna -Location westeurope -VmSize Standard_E2ds_v4
```

It takes about 15 minutes. At the end it prints a link that opens your workspace in
**Azure ML studio**.

When you're finished: `.\scripts\99-cleanup.ps1`

---

## 6. Step-by-step lab

In class, run the steps one at a time, and after each one look at what changed in the portal.

### Step 0 — Check prerequisites
```powershell
.\scripts\00-check-prerequisites.ps1 -Location eastus -VmSize Standard_E4ds_v4
```
**Concepts:** resource providers, RBAC, and **quota**. Quota is the maximum number of vCPUs
per VM family per region. A deployment can be syntactically perfect and still fail on quota,
so checking it first saves a failed 10-minute deployment.

### Step 1 — Validate without deploying
```powershell
.\scripts\01-validate-infra.ps1
```
**Concepts:** IaC is tested in layers, cheapest first:

| Check | Command | Catches |
|---|---|---|
| Lint | `az bicep lint` | Best-practice violations (rules in `bicepconfig.json`) |
| Build | `az bicep build` | Syntax and type errors, wrong property names |
| Params | `az bicep build-params` | Parameter-file mistakes |
| Preflight | `az deployment sub validate` | Invalid names, policy blocks, missing permissions |
| **What-if** | `az deployment sub what-if` | The exact list of creates (`+`), modifies (`~`) and deletes (`-`) |

**Observe:** the what-if output lists 11 resources to create. Run it again *after* deploying
and it shows "No change" (`=`). That shows the deployment is idempotent.

### Step 2 — Deploy the infrastructure
```powershell
.\scripts\02-deploy-infra.ps1
```
**Observe in the portal:**

- **Subscription → Deployments → `aml-olist-dev-eastus`**. Open it to watch each module deploy.
- **Resource group `rg-olist-ml-dev`**. Every resource carries the same tags (`project`,
  `environment`, `managedBy: bicep`).
- **Key Vault → Access control (IAM)**. The workspace's managed identity has been granted
  access. No password is involved.

The outputs (resource names, studio URL) are saved to `.deployment-outputs.json`. That is
how the next steps know which workspace to use.

### Step 3 — Upload the dataset
```powershell
.\scripts\03-upload-data.ps1
```
**Observe in Azure ML studio → Data → `olist-ecommerce-raw`:** version 1, its storage
location, and the **Explore** tab, which previews the files.

### Step 4 — Verify
```powershell
.\scripts\04-verify-deployment.ps1
```
This shows the workspace, the compute instance's state, the datastores, the data asset
versions, and your role assignments.

### Use the data from a notebook on the compute instance
Open **studio → Compute → your instance → JupyterLab**, then run:

```python
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
import pandas as pd

ml_client = MLClient.from_config(credential=DefaultAzureCredential())  # workspace config is pre-set on a compute instance
asset = ml_client.data.get(name="olist-ecommerce-raw", version="1")

orders = pd.read_csv(f"{asset.path}/olist_orders_dataset.csv")      # needs: pip install azureml-fsspec
orders.head()
```

In a training job, refer to the data as `azureml:olist-ecommerce-raw:1`.

---

## 7. How the Bicep code works

Read the files in this order: `main.bicep`, then `modules/ml-workspace.bicep`, then the other modules.

| Concept | Where to look | What it teaches |
|---|---|---|
| `targetScope = 'subscription'` | `main.bicep` | The template creates its own resource group, then deploys *into* it with `scope: resourceGroup` |
| Parameters and decorators | `main.bicep` | `@description`, `@allowed`, `@minLength`, `@minValue` validate input *before* anything is deployed |
| `.bicepparam` + `readEnvironmentVariable()` | `main.bicepparam` | One parameter file serves laptops (scripts set env vars) and CI/CD (pipeline env vars) |
| Naming with `uniqueString()` | `main.bicep` → `names` | A deterministic hash: same inputs give the same names, so redeploying *updates* instead of duplicating. Needed for globally unique names (storage, Key Vault, registry). |
| Modules | `modules/*.bicep` | Small, single-purpose, reusable building blocks |
| Implicit dependencies | `workspace` module params | Passing `storage.outputs.id` makes Bicep wait for storage. No `dependsOn` needed. |
| `existing` | `compute-instance.bicep`, `role-assignments.bicep` | Refer to a resource without creating it |
| `parent` | `compute-instance.bicep` | Child resources (a compute belongs to a workspace) |
| Conditional deployment | `if (deployComputeInstance)` | Optional parts of an environment |
| Role assignments | `role-assignments.bicep` | `guid(scope, principal, role)` gives a stable name, so redeploying never duplicates an assignment |
| `deployer()` | `main.bicep` | Defaults the data scientist to whoever runs the deployment |
| Outputs | end of `main.bicep` | Hand values to the next automation step. **Never output secrets.** |

Microsoft's naming abbreviations (Cloud Adoption Framework) are used throughout: `rg`,
`mlw`, `st`, `kv`, `cr`, `appi`, `log`.

---

## 8. Why the data upload is a separate step

|  | **Control plane** | **Data plane** |
|---|---|---|
| What | *Creating and configuring* resources | *Putting content into* them |
| Example | "Create a storage account" | "Upload these 9 CSV files" |
| Tool | Bicep / ARM (runs **inside Azure**) | Azure ML CLI v2 / SDK (runs **on your machine**) |

A Bicep deployment runs in Azure Resource Manager, so it **can't read files on your
laptop**. Deployment scripts also run in Azure, and `loadFileAsBase64()` is limited to
96 KB. That's why `03-upload-data.ps1` uses the CLI:

```powershell
az ml data create --file data/olist-data-asset.yml --version 1 -g <rg> -w <workspace>
```

This uploads the local folder to the workspace's default datastore (`workspaceblobstore`)
**and** registers the data asset in one command.

**Data assets are immutable.** Version 1 can never change. When the data changes, register
version 2 (`-DataVersion 2`). Every experiment then records exactly which data it used,
which is the basis of reproducible ML.

---

## 9. Configuration reference

Values are resolved in this order: script parameter → environment variable →
`main.bicepparam` default.

| Bicep parameter | Env variable | Default | Notes |
|---|---|---|---|
| `projectName` | `AML_PROJECT_NAME` | `olist` | 3–10 lowercase letters/digits. **Students sharing one subscription need different values.** |
| `environmentName` | `AML_ENVIRONMENT` | `dev` | `dev` / `test` / `prod` |
| `location` | `AZURE_LOCATION` | `eastus` | Any Azure ML region |
| `dataScientistObjectId` | `AML_USER_OBJECT_ID` | *(deployer)* | Entra object ID of the user who gets access and owns the compute instance |
| `deployComputeInstance` | `AML_DEPLOY_COMPUTE_INSTANCE` | `true` | The deploy script sets it to `false` when the instance already exists |
| `computeInstanceVmSize` | `AML_COMPUTE_VM_SIZE` | `Standard_E4ds_v4` | 4 vCPU / 32 GB. Cheaper: `Standard_E2ds_v4` (2 vCPU / 16 GB) |
| `computeInstanceIdleShutdownMinutes` | – | `30` | 15 minutes to 3 days |
| `computeInstanceScheduledStopCron` | – | `0 19 * * *` | Daily forced stop |
| `computeInstanceScheduleTimeZone` | – | `UTC` | Windows time-zone name, e.g. `India Standard Time` |
| `createContainerRegistry` | – | `true` | |

**An instructor creating an environment for a student:**
```powershell
$id = az ad user show --id student@school.edu --query id -o tsv
.\scripts\deploy-all.ps1 -ProjectName olistst01 -DataScientistObjectId $id
```

---

## 10. Cost control and cleanup

| Resource | Cost driver | Control |
|---|---|---|
| **Compute instance** | **Per hour while running.** This is the main cost. The disk is billed even when stopped. | Idle shutdown after 30 minutes, a daily scheduled stop, and `az ml compute stop` |
| Container Registry (Basic) | Small fixed daily fee (about US$5/month) | `createContainerRegistry = false` if you won't build images |
| Storage, Key Vault, Log Analytics, App Insights | Pennies at course scale | – |

Check current prices in the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/).

```powershell
# Stop / start the compute instance
az ml compute stop  --name <ci-name> -g rg-olist-ml-dev -w mlw-olist-dev
az ml compute start --name <ci-name> -g rg-olist-ml-dev -w mlw-olist-dev

# Delete EVERYTHING at the end of the course
.\scripts\99-cleanup.ps1
```

**Why cleanup is more than deleting the resource group.** Some services *soft-delete*, and
their names stay reserved:

| Resource | Soft-delete period | Cleanup action |
|---|---|---|
| Azure ML workspace | 14 days | `az ml workspace delete --permanently-delete` |
| Log Analytics | 14 days | `az monitor log-analytics workspace delete --force` |
| Key Vault | 7 days (set in `key-vault.bicep`) | `az keyvault purge` after the resource group is deleted |

---

## 11. Troubleshooting

| Error / symptom | Cause | Fix |
|---|---|---|
| `QuotaExceeded`, or the prerequisites check fails at step 7 | No vCPU quota for that VM family in the region | Pick a size from a family the check lists as free, or request quota (studio → Quota) |
| VM size not available | DSv2/DSv3 sizes (DS3_v2, DS11_v2) are being retired and new subscriptions can't deploy them | Use the default `Standard_E4ds_v4`, or another size the check approves |
| `VaultAlreadyExists` / vault "in deleted state" | A soft-deleted Key Vault still holds the name | `az keyvault list-deleted`, then `az keyvault purge --name <kv>` |
| Workspace name already in use after a cleanup | The workspace is soft-deleted | Recover it or purge it in the portal (Azure ML → Recently deleted), or use `--permanently-delete` |
| Compute instance name already exists | The name must be unique in the **whole region** | Use another `-ProjectName` (the suffix is derived from it) |
| Redeploy fails on the compute instance | Compute instances can't be redeployed in place | The deploy script skips existing instances. To change the size, delete the instance and redeploy. |
| `AuthorizationFailed ... roleAssignments/write` | You're Contributor without RBAC rights | Get Owner, or add Role Based Access Control Administrator |
| `RoleAssignmentExists` | The same role was already granted manually under another name | Delete the manual assignment, or remove that role from `role-assignments.bicep` |
| `UnmatchedPrincipalType` | The object ID isn't a *User* | Set `dataScientistPrincipalType` to `Group` or `ServicePrincipal` |
| `RequestDisallowedByPolicy` | An Azure Policy blocks a setting (often storage key access) | Ask your admin. Compute instances require storage account key access. |
| Upload fails with 403 right after deploying | Role assignments take a few minutes to take effect | Wait 5 minutes and rerun `03-upload-data.ps1` |
| `BCP081` warning: "does not have types available" | Your Bicep CLI is older than the API version | `az bicep upgrade` |

---

## 12. CI/CD with GitHub Actions (advanced)

`.github/workflows/deploy-azureml-infra.yml` turns this folder into a GitOps pipeline:

- **Pull request:** lint, build, and **what-if**, so reviewers see the planned changes.
- **Merge to `main`:** deploy. Add *required reviewers* on the GitHub environment to get an
  approval gate.
- **Login with OpenID Connect (OIDC):** GitHub exchanges a short-lived token with Entra ID,
  so **no secret is stored in GitHub**.

One-time setup. Make this folder the root of a GitHub repository first.

```powershell
$repo = 'your-org/your-repo'
$sub  = az account show --query id -o tsv
$tenant = az account show --query tenantId -o tsv

# 1. An identity for the pipeline
$appId = az ad app create --display-name 'gh-olist-azureml-infra' --query appId -o tsv
az ad sp create --id $appId | Out-Null

# 2. Permission to deploy. Owner is simplest on a teaching subscription.
#    In production use Contributor + Role Based Access Control Administrator.
az role assignment create --assignee $appId --role Owner --scope "/subscriptions/$sub"

# 3. Trust GitHub: one federated credential per kind of trigger
foreach ($fic in @(
    @{ name = 'main-branch';  subject = "repo:${repo}:ref:refs/heads/main" },
    @{ name = 'pull-request'; subject = "repo:${repo}:pull_request" },
    @{ name = 'env-dev';      subject = "repo:${repo}:environment:dev" })) {
  @{ name = $fic.name; issuer = 'https://token.actions.githubusercontent.com'
     subject = $fic.subject; audiences = @('api://AzureADTokenExchange') } |
     ConvertTo-Json | Set-Content fic.json
  az ad app federated-credential create --id $appId --parameters fic.json
}
Remove-Item fic.json

# 4. Repository secrets and variables (GitHub CLI)
gh secret set AZURE_CLIENT_ID       --body $appId
gh secret set AZURE_TENANT_ID       --body $tenant
gh secret set AZURE_SUBSCRIPTION_ID --body $sub
gh variable set AML_USER_OBJECT_ID  --body (az ad signed-in-user show --query id -o tsv)
```

The pipeline sets `AML_DEPLOY_COMPUTE_INSTANCE=false`. Compute instances can't be safely
redeployed on every merge, so create yours once with `02-deploy-infra.ps1`.

---

## 13. Design decisions

These follow Microsoft documentation (checked October 2026):

| Decision | Reason |
|---|---|
| Bicep, subscription scope, modules | Microsoft's recommended native IaC. It creates the resource group too, so the whole environment is code. |
| Azure ML API version `2026-05-01` | The newest stable version that Bicep CLI 0.46 has type definitions for, so property typos are caught at build time. `2026-07-01` exists; switch after `az bicep upgrade`. |
| Key Vault API `2026-02-01` | Key Vault control-plane API versions older than 2026-02-01 retire in February 2027 |
| `Standard_E4ds_v4` compute | Dv2/DSv2 sizes (the old DS3_v2 / DS11_v2 defaults) are end-of-life and blocked for new subscriptions. EDSv4 is supported for compute instances. |
| Storage key access **on**, `systemDatastoresAuthMode: AccessKey` | Compute instances require storage account key access. Identity-only storage is an advanced topic (Exercise 4). |
| Key Vault with **RBAC** authorization | Microsoft's recommended model. It avoids the documented problem of redeploys wiping access policies. |
| Own Log Analytics workspace | Otherwise Azure creates a hidden "managed" workspace in a separate resource group |
| Container Registry created explicitly | Otherwise Azure ML auto-creates one, with the admin user enabled, outside your code |
| Key Vault soft-delete 7 days, no purge protection | Lets classes tear down and redeploy. **Enable purge protection in production.** |
| Compute instance skipped when it exists | Azure warns that a PUT on an existing compute "will overwrite" it. VM size, SSH and idle settings are creation-time only. |
| Data uploaded with `az ml data create` | One command uploads and registers a versioned asset. Bicep can't read local files. |

---

## 14. Exercises

1. **Change and preview.** Change `retentionInDays` in `monitoring.bicep` to 60. Run
   `01-validate-infra.ps1` and find the `~ Modify` line in what-if, then deploy.
2. **A second environment.** Deploy a `test` environment beside `dev`
   (`-EnvironmentName test -SkipComputeInstance`). Which names changed, and why?
3. **Add a compute cluster.** Write `modules/compute-cluster.bicep` with
   `computeType: 'AmlCompute'`, `scaleSettings.minNodeCount: 0` and `maxNodeCount: 2`. Why
   does `minNodeCount: 0` matter for cost?
4. **Identity-based data access.** Set `systemDatastoresAuthMode: 'Identity'` and
   `allowSharedKeyAccess: false`. What breaks, and why? (Hint: compute instances; see
   *how-to-disable-local-auth-storage*.)
5. **Data versioning.** Register `-DataVersion 2` containing only the orders and reviews
   files. Compare both versions in studio.
6. **Deployment Stacks.** Deploy with
   `az stack sub create --name olist-dev --location eastus --parameters infra/main.bicepparam --action-on-unmanage deleteAll --deny-settings-mode none`.
   Then remove the container registry module and redeploy. What happens to the registry?
7. **Azure Verified Modules.** Replace `ml-workspace.bicep` with
   `br/public:avm/res/machine-learning-services/workspace`. What do you gain, and what do you lose?

---

## 15. References

- [What is Bicep?](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview) ·
  [Bicep best practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices) ·
  [Comparing Terraform and Bicep](https://learn.microsoft.com/azure/developer/terraform/comparing-terraform-and-bicep)
- [Bicep what-if](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-what-if) ·
  [Parameter files (.bicepparam)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/parameter-files) ·
  [Deployment stacks](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks)
- [Workspace template reference](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/workspaces) ·
  [Compute template reference](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/workspaces/computes)
- [Create a workspace with a template](https://learn.microsoft.com/azure/machine-learning/how-to-create-workspace-template) ·
  [Create a compute instance](https://learn.microsoft.com/azure/machine-learning/how-to-create-compute-instance) ·
  [Manage a compute instance](https://learn.microsoft.com/azure/machine-learning/how-to-manage-compute-instance)
- [Install the Azure ML CLI v2](https://learn.microsoft.com/azure/machine-learning/how-to-configure-cli) ·
  [Create data assets](https://learn.microsoft.com/azure/machine-learning/how-to-create-data-assets) ·
  [Data YAML schema](https://learn.microsoft.com/azure/machine-learning/reference-yaml-data)
- [Azure ML roles](https://learn.microsoft.com/azure/machine-learning/how-to-assign-roles) ·
  [Identity-based storage access](https://learn.microsoft.com/azure/machine-learning/how-to-disable-local-auth-storage) ·
  [Quotas](https://learn.microsoft.com/azure/machine-learning/how-to-manage-quotas)
- [Workspace soft delete](https://learn.microsoft.com/azure/machine-learning/concept-soft-delete) ·
  [Key Vault soft delete](https://learn.microsoft.com/azure/key-vault/general/soft-delete-overview) ·
  [VM size retirements](https://learn.microsoft.com/azure/virtual-machines/sizes/lifecycle/retirements-and-capacity-restrictions)
- [Bicep with GitHub Actions](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-github-actions) ·
  [OIDC from GitHub to Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect) ·
  [Resource naming abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

---

*Dataset: [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), CC BY-NC-SA 4.0.*
