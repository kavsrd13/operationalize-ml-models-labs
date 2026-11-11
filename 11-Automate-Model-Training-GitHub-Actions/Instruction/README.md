# Exercise 11: Automate model training with GitHub Actions

## Goal

Use a change to the freight training code to trigger an Azure ML training job. GitHub
signs in to Azure with OpenID Connect (OIDC), checks the existing course assets, then
submits exercise 03's job and reports whether it completed.

## Before you start

1. Complete exercises 00 and 03 in one Azure ML workspace. Confirm the shared
   `olist-course-cpu` compute and `olist-ecommerce-raw:1` data asset exist. Keep the
   cluster minimum node count at zero.
2. Put this **collection's contents at the root of your own GitHub repository**.
   The workflow must be at `.github/workflows/train-freight.yml` relative to that root.
   GitHub Actions runs from the repository root; a nested workflow is not discovered.
   Install and sign in to GitHub CLI (`gh auth login`) for the identity commands below.
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
   An Azure administrator can run the following in PowerShell after setting
   `$RG`, `$WS`, `$OWNER`, and `$REPO` to the student's values:

   ```powershell
   $APP_ID = az ad app create --display-name "olist-course-github-$REPO" --query appId -o tsv
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
   and `AZURE_ML_WORKSPACE` with the names from exercise 00. These IDs are not
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
10. Edit one harmless setting in `03-Freight-Regression-Training/jobs/train-job.yml`,
    such as `display_name`, and commit it to `main`. The `push` trigger should start
    another workflow run automatically. Compare its new Azure ML job name with step 9.
11. Commit a change outside the three watched paths, such as this instruction file.
    Verify that the freight training workflow does not start for that commit.
12. Set `ENABLE_AZURE_TRAINING` back to `false` when finished. The shared compute
    scales to zero; delete only job outputs or identity permissions that you own and
    no longer need.

## If a run fails

- **Login failed:** compare the exact subject printed in `AADSTS700213` with
  the federated credential, including numeric IDs in an immutable subject.
  Also check client, tenant, and subscription IDs.
- **Resource check failed:** run exercise 00 again with `--create-cluster`, verify the
  same workspace variables, and check the OIDC identity's workspace role.
- **Training failed:** open the Azure ML job link or job name in Studio and read
  `user_logs/std_log.txt`. The workflow reports the actual Azure ML final status.
- **Azure ML logs are needed:** use Studio or `az ml job download -n JOB_NAME
  -g RESOURCE_GROUP -w WORKSPACE --all`. The workflow polls job status; it does
  not depend on the CLI log-stream command, which can fail with `Incorrect padding`.

## Validation status

The workflow and YAML are checked locally. The GitHub OIDC run requires each learner's
own repository identity and has not yet been executed in GitHub Actions.
