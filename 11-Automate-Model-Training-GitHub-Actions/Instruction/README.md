# Exercise 11: Automate model training with GitHub Actions

## Goal

Use a change to the freight training code to trigger an Azure ML training job. GitHub
signs in to Azure with OpenID Connect (OIDC), checks the existing course assets, then
submits this exercise's own job and reports whether it completed.

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

- [`train.py`](../src/train.py)
- [`train-job.yml`](../jobs/train-job.yml)
- [`train-freight.yml`](../../.github/workflows/train-freight.yml)

Run commands from the repository root. Olist's source ZIP is stored once in `datasets/olist` and extracted by setup.


## Before you start

1. Confirm the setup above created `course-cpu` and `olist-ecommerce-raw:1`.
   Read this lab's `src/train.py` and `jobs/train-job.yml` to understand the
   training code that GitHub Actions will submit. Keep the cluster minimum at zero.
2. Create a private repository under your own GitHub account and push this clone
   to it. The workflow must be at `.github/workflows/train-freight.yml` at the
   repository root; GitHub does not discover nested workflows. Use a new name
   for `$REPO` and keep the course repository as the `origin` remote:

   ```powershell
   $OWNER = gh api user --jq '.login'
   $REPO = 'my-azure-ml-training-lab'
   gh repo create "$OWNER/$REPO" --private --source . --remote student --push
   gh repo view "$OWNER/$REPO" --web
   ```
3. Ask an Azure administrator for permission to create a Microsoft Entra
   application, service principal, and workspace role assignment for this
   repository. The identity needs **AzureML Data Scientist** on the course
   workspace; it does not need to create another compute cluster.
4. Add a federated credential with issuer
   `https://token.actions.githubusercontent.com`, audience
   `api://AzureADTokenExchange`, and the exact GitHub OIDC subject for `main`.
   New GitHub repositories use an **immutable subject** containing numeric owner
   and repository IDs: `repo:OWNER@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main`.
   Older repositories may still use `repo:OWNER/REPO:ref:refs/heads/main`.
   The subject is case-sensitive; use the format your repository issues.
   An Azure administrator can run the following in PowerShell using `$RG`,
   `$WS`, `$OWNER`, and `$REPO` from the steps above:

   ```powershell
   $APP_ID = az ad app create --display-name "course-github-$REPO" --query appId -o tsv
   az ad sp create --id $APP_ID
   $SP_OBJECT_ID = az ad sp show --id $APP_ID --query id -o tsv
   $WORKSPACE_ID = az ml workspace show -n $WS -g $RG --query id -o tsv
   az role assignment create --assignee-object-id $SP_OBJECT_ID `
     --assignee-principal-type ServicePrincipal --role 'AzureML Data Scientist' `
     --scope $WORKSPACE_ID
   $OWNER_ID = gh api "repos/$OWNER/$REPO" --jq '.owner.id'
   $REPO_ID = gh api "repos/$OWNER/$REPO" --jq '.id'
   $credential = @{
     name = 'github-main'
     issuer = 'https://token.actions.githubusercontent.com'
     subject = "repo:${OWNER}@${OWNER_ID}/${REPO}@${REPO_ID}:ref:refs/heads/main"
     audiences = @('api://AzureADTokenExchange')
   }
   $credential | ConvertTo-Json | Set-Content -Encoding utf8 .\github-oidc.json
   az ad app federated-credential create --id $APP_ID --parameters .\github-oidc.json
   Remove-Item .\github-oidc.json
   az account show --query tenantId -o tsv
   ```

   Use `$APP_ID` for `AZURE_CLIENT_ID`, the last command's tenant ID for
   `AZURE_TENANT_ID`, and `az account show --query id -o tsv` for the subscription.
5. In GitHub **Settings → Secrets and variables → Actions**, add repository secrets
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` from that
   application and subscription. Add repository variables `AZURE_RESOURCE_GROUP`
   and `AZURE_ML_WORKSPACE` with `$RG` and `$WS` above. These IDs are not
   passwords, but keep them in GitHub settings so the workflow can be reused.

Microsoft's [OIDC setup guide](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)
shows the portal screens for the app and federated credential. GitHub's
[OIDC reference](https://docs.github.com/en/actions/reference/security/oidc)
explains immutable subjects for newer repositories. If the sign-in step reports
`AADSTS700213`, copy the **presented assertion subject** from the failed run
and make the federated credential match it exactly.

## Run the exercise

6. Open `.github/workflows/train-freight.yml`. Identify the `push` file paths, the
   `id-token: write` permission, the OIDC login, and the final-status polling loop.
7. In GitHub Actions variables, set `ENABLE_AZURE_TRAINING` to `true`. This gate
   prevents an automatic Azure job when the materials are first published.
8. In **Actions → Train freight model in Azure ML**, choose **Run workflow** on
   `main`. The run checks the shared compute and asset before submitting training.
9. Open the run logs. Record the Azure ML job name. In Azure ML Studio, open that
   job and inspect its `Completed` status, MAE, baseline comparison, and model output.
   The GitHub run must also finish green and show `Completed` in its summary.
10. Edit one harmless setting in `11-Automate-Model-Training-GitHub-Actions/jobs/train-job.yml`,
    such as `display_name`, and push it to your repository. The `push` trigger
    should start another workflow run automatically. Compare its Azure ML job
    name with step 9:

    ```powershell
    git add .\11-Automate-Model-Training-GitHub-Actions\jobs\train-job.yml
    git commit -m "Exercise 11: update training display name"
    git push student main
    ```

11. Commit a change outside the three watched paths, such as this instruction file,
    and push it to `student main`.
    Verify that the freight training workflow does not start for that commit.
12. Set `ENABLE_AZURE_TRAINING` back to `false` when finished. The shared compute
    scales to zero; delete only job outputs or identity permissions that you own and
    no longer need.

## If a run fails

- **Login failed:** compare the exact subject printed in `AADSTS700213` with
  the federated credential, including numeric IDs in an immutable subject.
  Also check client, tenant, and subscription IDs.
- **Resource check failed:** rerun the setup above, verify the
  same workspace variables, and check the OIDC identity's workspace role.
- **Training failed:** open the Azure ML job link or job name in Studio and read
  `user_logs/std_log.txt`. The workflow reports the actual Azure ML final status.
- **Azure ML logs are needed:** use Studio or `az ml job download -n JOB_NAME
  -g RESOURCE_GROUP -w WORKSPACE --all`. The workflow polls job status; it does
  not depend on the CLI log-stream command, which can fail with `Incorrect padding`.

## Validation status

An earlier version of this workflow completed a live GitHub Actions → Azure ML
training run in the course test workspace on 11 November 2026. The temporary
identity, GitHub settings, and test compute were removed afterward. The current
standalone paths and generic compute name have not yet been rerun live. Each
learner must configure their own repository identity and Azure ML resources.
See `../../SHARED_COMPUTE_AND_GITHUB_VALIDATION_2026-11-11.md` for the run record.
