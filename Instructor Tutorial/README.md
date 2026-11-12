# Instructor Tutorial (Diabetes end-to-end on Azure ML)

This tutorial gives you a clean, script-first flow to teach:

1. Spin up Azure resources with Bicep  
2. Register a data asset and create compute resources with Azure CLI  
3. Submit a command job and register a trained model  
4. Deploy the model to a managed online endpoint and invoke it  

> This tutorial uses the repository's sample dataset at `data/diabetes-data/diabetes.csv`.

---

## Prerequisites

- Azure subscription with permissions to create resource groups and Azure ML resources
- Azure CLI (`az`) installed
- Azure ML extension installed:
  ```powershell
  az extension add --name ml --upgrade
  ```
- Logged in:
  ```powershell
  az login
  ```

---

## Folder structure

- [01-Spin-Up-Azure-Resources-Bicep](./01-Spin-Up-Azure-Resources-Bicep)
- [02-Register-Data-And-Create-Compute](./02-Register-Data-And-Create-Compute)
- [03-Train-Command-Job-And-Register-Model](./03-Train-Command-Job-And-Register-Model)
- [04-Deploy-Online-Endpoint](./04-Deploy-Online-Endpoint)

---

## Step-by-step runbook

Run from the repository root:

```powershell
cd "C:\Users\kvsrd\OneDrive\Desktop\Tess\operationalize-ml-models-labs"
```

### Step 1 - Provision Azure ML core resources with Bicep

```powershell
.\Instructor Tutorial\01-Spin-Up-Azure-Resources-Bicep\deploy.ps1 `
  -ResourceGroupName "rg-diabetes-instructor" `
  -Location "eastus" `
  -NamePrefix "diabinst01"
```

This creates:
- Azure Storage account
- Key Vault
- Application Insights
- Container Registry
- Azure ML Workspace

It also writes [tutorial.env](./tutorial.env), which later steps use.

### Step 2 - Register data + create compute instance and cluster

```powershell
.\Instructor Tutorial\02-Register-Data-And-Create-Compute\register-data-and-compute.ps1
```

This registers `diabetes-data` and creates:
- `ci-diabetes` (Compute Instance)
- `cpu-cluster` (AmlCompute cluster)

### Step 3 - Submit command job + register model

```powershell
.\Instructor Tutorial\03-Train-Command-Job-And-Register-Model\submit-job-and-register-model.ps1 `
  -ModelName "diabetes-sklearn-model"
```

This runs a command job using:
- [train-diabetes.py](./03-Train-Command-Job-And-Register-Model/src/train-diabetes.py)
- [job.yml](./03-Train-Command-Job-And-Register-Model/job.yml)

Then it registers the output model in Azure ML.

### Step 4 - Deploy model to managed online endpoint

```powershell
.\Instructor Tutorial\04-Deploy-Online-Endpoint\deploy-online-endpoint.ps1 `
  -ModelName "diabetes-sklearn-model" `
  -EndpointName "diabetes-endpoint-demo-001"
```

This creates:
- Managed online endpoint
- `blue` deployment
- 100% traffic to `blue`

Then it invokes the endpoint with [sample-request.json](./04-Deploy-Online-Endpoint/sample-request.json).

---

## Cleanup (important to avoid extra cost)

Delete the resource group created in step 1:

```powershell
az group delete --name rg-diabetes-instructor --yes --no-wait
```

---

## Microsoft documentation references

- Azure ML resource type (Bicep):  
  https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/workspaces
- Create and manage data assets (CLI v2):  
  https://learn.microsoft.com/azure/machine-learning/how-to-create-data-assets?view=azureml-api-2
- Create compute instance (CLI v2):  
  https://learn.microsoft.com/azure/machine-learning/how-to-create-compute-instance?view=azureml-api-2
- Create compute cluster (CLI v2):  
  https://learn.microsoft.com/azure/machine-learning/how-to-create-attach-compute-cluster?view=azureml-api-2
- Train model with CLI/SDK:  
  https://learn.microsoft.com/azure/machine-learning/how-to-train-model?view=azureml-api-2
- Work with registered models:  
  https://learn.microsoft.com/azure/machine-learning/how-to-manage-models?view=azureml-api-2
- Deploy online endpoints:  
  https://learn.microsoft.com/azure/machine-learning/how-to-deploy-online-endpoints?view=azureml-api-2
- Deploy MLflow models to online endpoints:  
  https://learn.microsoft.com/azure/machine-learning/how-to-deploy-mlflow-models-online-endpoints?view=azureml-api-2
