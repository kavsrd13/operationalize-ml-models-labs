# Exercise 13: Foundry data analyst agent with automatic versioning

## Goal

Create a versioned Microsoft Foundry prompt agent with Code Interpreter and four small, related Olist CSV files. Ask it a data question in your terminal. Then edit its system instruction, push to your own GitHub repository, watch GitHub Actions register a new agent version through OIDC, and chat with the latest version in Streamlit.

The agent uses an existing model deployment. It does not train or fine-tune a model. Code Interpreter runs Python against uploaded CSV files when analysis is needed.

## Before you start

- A GitHub account and an Azure subscription where you can create or use a Foundry project, deploy a chat model, create a user-assigned managed identity, assign a role, and use Code Interpreter.
- Git, Python 3.11, PowerShell, Azure CLI, and GitHub CLI on your laptop.
- Your own copy of this repository, created with **Use this template**. Setup must run from that copy, not the instructor repository.
- A Foundry account and project with a working chat model deployment. The example test used `gpt-4.1-mini`; your deployment name can differ. Model calls and Code Interpreter use billable Azure capacity.

## Step 1: Create your own repository and clone it

1. Open [the course repository](https://github.com/kavsrd13/operationalize-ml-models-labs).
2. Select **Use this template** → **Create a new repository**. Choose your GitHub account, use `main` as the default branch, and create the repository.
3. Clone your new repository and enter it. Replace both placeholders:

```powershell
git clone https://github.com/YOUR-GITHUB-USERNAME/YOUR-REPOSITORY-NAME.git
Set-Location .\YOUR-REPOSITORY-NAME
git switch main
git remote get-url origin
```

The last command must show your repository, not the instructor repository. All later commands run from this repository root.

## Step 2: Prepare a Foundry project and model

1. Open [Microsoft Foundry](https://ai.azure.com/) and choose your subscription.
2. Open an existing **Foundry project**, or create a Foundry resource and project if you have none. Record the **resource group**, **Foundry account name**, and **project name** from the Azure portal resource overview.
3. In the project, open **Models** → **Deployments**. Use an existing chat model deployment, or deploy a supported model such as `gpt-4.1-mini` where quota is available. Wait for **Succeeded**. Record the **deployment name** shown in the table; this is the name the SDK uses.
4. Confirm your user can build agents in this project. Assign yourself **Foundry User** (previously **Azure AI User**) at project scope if necessary. Subscription **Owner** alone does not grant Foundry data-plane access.

## Step 3: Check sign-ins and install Python packages

Only sign in if the existing CLI session is not already for the intended accounts:

```powershell
az account show --output table
gh auth status
```

If needed, run `az login --use-device-code` and/or `gh auth login` once. Then install:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r .\13-Foundry-Data-Analyst-Agent\requirements.txt
```

## Step 4: Connect your GitHub repository to the project

```powershell
.\13-Foundry-Data-Analyst-Agent\setup.ps1
```

Select your Azure subscription by typing its displayed number. Enter the four names you recorded in Step 2: resource group, Foundry account, project, and model deployment. The script detects your GitHub repository from `origin`, verifies the project and deployment, creates a user-assigned identity with an OIDC trust restricted to your repository's `main` branch, assigns **Foundry User** on the project, and saves the GitHub Actions settings. It prints the project endpoint. It does not ask you to log in again.

If PowerShell says the script cannot be found, run `Get-Location` and make sure you are at the repository root. If script execution is blocked, run `Set-ExecutionPolicy -Scope Process Bypass` in the same terminal and rerun the script.

## Step 5: Publish and test the first agent version locally

Set these values using the endpoint printed by setup and the deployment name from Step 2:

```powershell
$env:FOUNDRY_PROJECT_ENDPOINT = 'https://YOUR-ACCOUNT.services.ai.azure.com/api/projects/YOUR-PROJECT'
$env:FOUNDRY_MODEL_DEPLOYMENT = 'YOUR-MODEL-DEPLOYMENT'
$env:ANALYST_AGENT_NAME = 'olist-data-analyst'
python .\13-Foundry-Data-Analyst-Agent\publish.py
python .\13-Foundry-Data-Analyst-Agent\chat.py
```

`publish.py` uploads `orders.csv`, `order_items.csv`, `customers.csv`, and `sellers.csv` from the exercise `data` folder. It registers the first version of the `olist-data-analyst` prompt agent with the instruction in `instructions/system.txt` and Code Interpreter. No local dataset path is needed at chat time: the agent version references the uploaded files.

At the `You:` prompt, enter:

```text
How many orders and order items are in the sample? Use Code Interpreter to read the CSV files and show the counts.
```

Expected: **300 orders** and **340 order items**. The terminal should also say **Code Interpreter ran for this answer**. Next ask:

```text
Which seller states have the highest total item price? Join the needed files, show the top five, and name the join key.
```

Check that the answer uses `seller_id` to join `order_items.csv` and `sellers.csv`, shows calculated values, and says this is a teaching sample. Type `exit` to close chat.

## Step 6: Change the agent instruction and push

Open `13-Foundry-Data-Analyst-Agent/instructions/system.txt`. At the end, add:

```text
Finish every answer with one short sentence beginning "Takeaway: ".
```

Save the file. Then run:

```powershell
git add .\13-Foundry-Data-Analyst-Agent\instructions\system.txt
git commit -m "Improve data analyst agent explanation"
git push origin main
```

Open your GitHub repository → **Actions** → **Exercise 13 - Publish Foundry data analyst agent**. The push should start a run. Open its **Upload CSVs and register new agent version** step and verify it prints a new version number. The workflow also asks the agent a sample question. Each instruction or CSV edit pushed to `main` creates another version; ordinary changes elsewhere do not trigger this workflow. The instructor source repository skips this job.

In Foundry, open **Build** → **Agents** → `olist-data-analyst` and compare its versions. The previous version remains available, while requests by agent name use the newest version.

## Step 7: Chat with the newest agent in Streamlit

Keep the same terminal and environment variables from Step 5:

```powershell
streamlit run .\13-Foundry-Data-Analyst-Agent\app.py
```

Open the local URL printed by Streamlit. Ask **How many orders and order items are in the sample?** and then ask a follow-up about sellers. The answer should use the new `Takeaway:` ending after the GitHub workflow completes. **New conversation** clears the chat history. Streamlit runs locally on your machine; Foundry runs the agent and Code Interpreter in Azure.

## Check your result

- Four linked CSV files appear in the exercise folder and were uploaded during publish.
- The terminal gives the expected counts and reports Code Interpreter use.
- Foundry shows at least two versions of `olist-data-analyst` after your push.
- The GitHub workflow succeeded using OIDC; no Azure password or API key is stored in the repository.
- Streamlit answers a question using the newest instruction.

## Cleanup

When finished, delete the agent versions and uploaded files from your Foundry project if you no longer need them. Remove the `id-olist-analyst-gh-*` identity and its project role assignment from the resource group, and delete the model deployment or entire dedicated project if it was created only for this lab. Model and Code Interpreter usage can incur charges.

## References

- [Azure AI Projects Python SDK and Code Interpreter](https://learn.microsoft.com/python/api/overview/azure/ai-projects-readme)
- [Foundry role-based access control](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry)
- [Azure Login action with OIDC](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended)
