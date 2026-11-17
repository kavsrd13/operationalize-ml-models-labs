# Azure pricing agent on Microsoft Foundry

A GPT-5 prompt agent that retrieves **live public Azure Retail Prices API** meters through a Foundry-managed OpenAPI toolbox and calculates itemized low/base/high estimates in native Code Interpreter. The agent is created with **Azure AI Projects SDK**, not a GitHub-hosted runtime.

This folder is self-contained and does not depend on the other labs. It packages the native implementation used by the verified deployment; publishing or running its local tests does not change that deployment. No endpoint, subscription ID, credentials, conversation history or raw deployment diagnostics are committed.

## Architecture and files

```text
Foundry Playground / Python ask client
  -> GPT-5 prompt agent
       -> Foundry-managed toolbox MCP endpoint
            -> OpenAPI GET https://prices.azure.com/api/retail/prices
       -> native Code Interpreter, networking disabled
            -> uploaded pricing_math.py -> report and evidence JSON
```

There is no local tool callback, HTTP backend, external MCP hosting, container image or GitHub Actions dependency. GitHub stores the source; Foundry executes the agent and tools.

| File | Purpose |
| --- | --- |
| `foundry_native_pricing.py` | SDK deployment, instructions, OpenAPI tool definition and pinned-version invocation |
| `pricing_math.py` | Standard-library Decimal calculator with evidence and unit validation |
| `azure_retail_prices.openapi.json` | Inspectable source OpenAPI schema, also generated during deployment |
| `infra/main.bicep` | Dedicated Foundry account, child project and GPT-5 deployment |
| `verify_native_report.py` | Compare downloaded sandbox report with actual API calls and interpreter output |
| `test_*.py` | Offline calculator, configuration and native-client regression tests |

## 1. Prerequisites

Use Python **3.11 or newer**, Azure CLI, an Azure subscription and an Entra identity permitted to provision the selected resources. The SDK versions in `requirements.txt` are pinned to the verified native API surface.

The project must be a **Foundry account project**, with an endpoint shaped like `https://<account-subdomain>.services.ai.azure.com/api/projects/<project>`. An older Azure Machine Learning hub/project endpoint is not interchangeable.

The chosen region must support Foundry agents, Code Interpreter, OpenAPI toolboxes and a deployable GPT-5 version. Check [model availability](https://learn.microsoft.com/azure/foundry/openai/concepts/models) and [quota](https://learn.microsoft.com/azure/foundry/openai/quotas-limits) before provisioning. The template defaults to `GlobalStandard`, GPT-5 `2025-08-07`, capacity 50; these are the verified release settings, **not an availability guarantee**. GlobalStandard can process outside the resource's region.

From the repository root, in PowerShell:

```powershell
Set-Location .\azure-pricing-agent
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r .\requirements.txt
az login
az account set --subscription "<your-subscription-id>"
```

All subsequent Python examples use that virtual environment. Use Azure CLI's interactive authentication; do not put API keys or tokens into source files.

## 2. Set up infrastructure, or reuse an existing project

### Option A: create a dedicated account, project and GPT-5 deployment

**The following commands create Azure resources and can incur charges.** Review your subscription, region, quota and organization policies first. Do not run them against the existing live agent merely to publish or test this repository.

The Bicep template creates an `AIServices` account with project management enabled, system-assigned identities for the account and project, **API-key/local authentication disabled**, and a public HTTPS endpoint protected by Entra/RBAC. It does not create role assignments, storage accounts, Search, application hosting or private networking. This is basic managed-agent setup, not an enterprise private-network deployment.

Choose a globally unique lowercase account/subdomain name:

```powershell
$resourceGroup = "rg-my-azure-pricing"
$location = "eastus"
$accountName = "<globally-unique-foundry-account-name>"

az provider register --namespace Microsoft.CognitiveServices --wait
az group create --name $resourceGroup --location $location
az deployment group what-if --resource-group $resourceGroup --template-file .\infra\main.bicep --parameters accountName=$accountName modelCapacity=50
```

After reviewing the preview:

```powershell
az deployment group create --name pricing-infra --resource-group $resourceGroup --template-file .\infra\main.bicep --parameters accountName=$accountName modelCapacity=50
```

If needed, explicitly supply `location`, `projectName`, `modelDeploymentName`, `modelVersion` and `modelCapacity`. `modelDeploymentName` is the name passed to the SDK, not necessarily the model catalog name. The template deliberately does not auto-upgrade the pinned model; update it after checking support/retirement notices. Quota or capacity errors need a supported region/version/allocation, not a silently substituted model.

Load the actual deployment outputs:

```powershell
$outputs = az deployment group show --name pricing-infra --resource-group $resourceGroup --query properties.outputs --output json | ConvertFrom-Json
$env:AZURE_AI_PROJECT_ENDPOINT = $outputs.projectEndpoint.value
$env:AZURE_AI_PROJECT_ARM_ID = $outputs.projectArmId.value
$env:AZURE_AI_MODEL_DEPLOYMENT = $outputs.modelDeployment.value
```

These commands require [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and its [Bicep support](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install). The template can be compiled offline with `az bicep build --file .\infra\main.bicep --stdout`.

### Option B: use an existing Foundry account project

Skip infrastructure creation. In Foundry/ Azure portal, copy the **project endpoint**, **project ARM resource ID** and name of an existing **GPT-5 model deployment**:

```powershell
$env:AZURE_AI_PROJECT_ENDPOINT = "https://<subdomain>.services.ai.azure.com/api/projects/<project-name>"
$env:AZURE_AI_PROJECT_ARM_ID = "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<account-name>/projects/<project-name>"
$env:AZURE_AI_MODEL_DEPLOYMENT = "<existing-gpt-5-deployment-name>"
```

Do not paste placeholders unchanged. Both target values are required for `deploy`: the endpoint is used by the Projects SDK; the ARM ID is used to create project connections. They must identify the same actual project.

### Permissions before SDK deployment

Ask your Azure administrator to apply scoped [Foundry RBAC assignments](https://learn.microsoft.com/azure/foundry/concepts/rbac-foundry):

* The infrastructure operator needs management permissions to create the resource group/account/project/model. Role assignments separately require authorized role-management permissions; resource Contributor alone cannot grant roles.
* The agent developer needs **Foundry User** (previously **Azure AI User**) at the project and Reader at the account, plus permission to create the two project connections. Verify [connection permissions](https://learn.microsoft.com/azure/foundry/how-to/connections-add) in your tenant. Use a scoped additional/custom role if required; do not grant subscription Owner to the client.
* Give the **project's managed identity Foundry User at its parent Foundry account**, as required by the documented basic setup. The template creates the identity but intentionally does not grant this role.
* The toolbox connection uses **UserEntraToken**, audience `https://ai.azure.com`: the calling identity must be permitted to invoke the project's toolbox. Anonymous auth applies only to the public Retail API, not the Foundry project.

Roles may still appear under their previous Azure AI names. Wait for RBAC propagation before deploying. For production applications use a managed identity and an appropriate least-privilege runtime role instead of an interactive CLI login; this example deliberately uses `AzureCliCredential` for local operator deployment/invocation. Nothing in the script grants roles or embeds secrets.

## 3. Deploy the native agent using Azure AI Projects SDK

Optional names:

```powershell
$env:AZURE_AI_AGENT_NAME = "azure-pricing-advisor"
$env:AZURE_AI_TOOLBOX_NAME = "azure-retail-pricing"
.\.venv\Scripts\python.exe .\foundry_native_pricing.py deploy
```

The command:

1. Creates/reuses `azure-retail-prices-anonymous`, an OpenAPI project connection with auth `None`. Even anonymous OpenAPI requires a project connection.
2. Uploads `pricing_math.py` for native Code Interpreter.
3. Creates and reads back an OpenAPI toolbox version; promotes it as that toolbox's default.
4. Creates/reuses `azure-pricing-toolbox`, a RemoteTool/UserEntraToken connection pointing at the Foundry-managed toolbox MCP endpoint.
5. Calls `AIProjectClient.agents.create_version(PromptAgentDefinition(...))` with the configured GPT-5 deployment, MCP tool and network-disabled native Code Interpreter, then checks persisted readback.
6. Saves the actual agent name/version, uploaded file ID, toolbox version, connections and definitions under ignored `.foundry\`.

**This is a cloud write, not a dry run.** Redeployment creates new agent/toolbox versions and uploads a new file. It also changes the toolbox default, so agents sharing that unversioned toolbox endpoint use the new default. Use dedicated names/projects for independent environments. Fixed connection names are project-scoped; an existing mismatched connection fails explicitly rather than being overwritten.

The two reusable connections are managed through ARM API `2025-10-01-preview`; agent/toolbox operations use the pinned Projects SDK. Preview availability can vary. Deployment is not transactional: a later failure can leave an uploaded file, connection or toolbox version. Inspect and clean up those named resources before retrying; the script does not delete unrelated state.

The saved `.foundry\deployment.json` pins **agent version** for invocation. Keep local state private and backed up; it is not a transferable Azure resource or conversation export. `--config <path>` selects another saved configuration for both `deploy` and `ask`.

## 4. Test in the Playground or the Python client

Open your project in [Foundry](https://ai.azure.com/), select the deployed agent name/version and use its Playground. A simple prompt:

> Estimate the monthly USD cost of one Linux Standard_D2s_v3 VM running 730 hours in East US using current Azure retail prices, and list excluded costs.

The agent may ask for missing low/high quantities, resilience or other essential inputs rather than inventing them. A fully specified two-service native-tool smoke prompt:

```powershell
$prompt = "Estimate public PAYG USD pricing in eastus for Linux Standard_D2s_v3 VM aggregate monthly hours low 365/base 730/high 1460 and Key Vault Standard Operations monthly counts low 100000/base 1000000/high 10000000. Assume one region, no resilience replica or other workload. Exclude disks, egress, backup and monitoring and keep them explicitly unpriced. Retrieve exact current meters, calculate all scenarios with the uploaded calculator in one report and save the report plus exact API evidence as downloadable JSON."
.\.venv\Scripts\python.exe .\foundry_native_pricing.py ask --question $prompt
```

The response and tool outputs are saved to `.foundry\response.json`. The client makes no local pricing callbacks. It invokes the saved version with OpenAI Responses `extra_body.agent_reference`, **not classic threads/runs**.

For a clarification follow-up, use the conversation ID printed by the client:

```powershell
.\.venv\Scripts\python.exe .\foundry_native_pricing.py ask --conversation "<conversation-id>" --question "<your answer>"
```

`--max-output-tokens` accepts 1-12,000 (default 8,000). SDK auto-retries are disabled; incomplete responses are preserved and reported as errors. Reducing the output budget may help token-limit 429s, but does not fix missing permissions or tool availability.

### Download and verify native evidence

Download the agent's JSON sandbox file promptly in the Playground; sandbox files can expire. It must contain `{"report": ..., "lookups": ...}`. Use the saved response from the **same invocation**:

```powershell
.\.venv\Scripts\python.exe .\verify_native_report.py .\.foundry\response.json .\.foundry\downloaded-report.json --output .\.foundry\reconciliation.json
```

The verifier requires completed real MCP calls and nonempty interpreter execution. It checks saved URL arguments and original API pages against actual tool output, downloaded JSON against emitted interpreter JSON, and independently recomputes emitted Decimal tier charges, rounded subtotals and annual projections. It is an evidence consistency check, not a complete Azure billing audit. Do not run it with Python `-O`.

The original native release verified four API calls and one nonempty interpreter call for the two-service scenario above. On **2026-11-17**, its exact API evidence showed Linux VM `0.096 USD/hour` and Key Vault `0.03 USD/10,000 operations`:

| Scenario | Monthly priced subtotal | Annual priced projection |
| --- | ---: | ---: |
| Low | $35.34 | $424.08 |
| Base | $73.08 | $876.96 |
| High | $170.16 | $2,041.92 |

These are dated reference results, not hardcoded agent rates, a current-price promise or an all-in bill. Local packaging checks do not constitute a new cloud deployment or fresh native pricing run.

## 5. Offline checks

```powershell
.\.venv\Scripts\python.exe -m unittest discover -v
.\.venv\Scripts\python.exe -m py_compile .\foundry_native_pricing.py .\pricing_math.py .\verify_native_report.py
az bicep build --file .\infra\main.bicep --stdout
```

Tests use synthetic pricing fixtures and mocked cloud clients, not paid model requests. They cover complete multi-page tiers, exact identities/SKUs, conflicting rates, unsupported units, Key Vault's contextual `10K` unit, commitment rejection, stale/incomplete evidence, partial totals, deployment configuration, native tool serialization and explicit client failure handling. A successful Bicep compile validates template shape, not regional capacity or a live deployment.

## Coverage and pricing boundaries

| Capability | Release support |
| --- | --- |
| Commercial public catalog discovery | Any service exposed by the Retail Prices API; no permanent service shortlist |
| Validated calculator | Explicit numeric Hour/Month/GB/GiB/TB and Transactions/Requests/Tokens/Operations, including K/M scales; complete Consumption tiers starting at zero |
| Contextual bare unit | `10K` only for exact Key Vault / Key Vault / Standard / Operations / Consumption metadata |
| Native end-to-end service verification | Linux PAYG VM compute and Key Vault Standard Operations |
| Complete service/scenario billing | **Not claimed**; output is always `partial_meter_estimate` |

The agent discovers actual product/meter names rather than guessing. ARM SKU filters use `armSkuName`; region, OS/licensing, currency and price type must match. It never selects a cheapest ambiguous rate. API work is bounded to four pages per lookup, eight narrowed lookups and forty priced lines; unfinished groups cannot be calculated. Price evidence must be less than ten minutes old.

The calculator rejects compound units such as `1 GB/Month`. It does not infer allowances, minimum bills, included capacity, shared-account aggregation, automatic sizing, disk/network/backup/monitoring dependencies or discounted eligibility. Unsupported/unpriced components stay visible; a valid zero rate is different from unsupported coverage.

Reservations and savings plans can be discovered but are **not calculated**. Reservation term prices must not be multiplied as hourly prices just because the API says Hour. Spot, DevTest, licenses and discount plans are not interchangeable with ordinary PAYG. No incompatible discounts are stacked.

730 hours is an explicitly accepted convention, not an automatic month. Low/base/high are supplied usage sensitivities, not statistical confidence intervals. Annual output is twelve times the monthly priced subtotal, not an annual commitment quote. USD is authoritative public retail pricing; other currencies are reference budgets. Government, China, Marketplace, contracts/negotiated rates, credits and taxes are outside this release.

## Troubleshooting, costs and cleanup

* **401/403:** Check the active `az login` tenant/subscription, project endpoint and RBAC; verify the project identity assignment and UserEntraToken toolbox connection. Do not solve Entra errors by enabling keys.
* **ResourceNotFound:** Use the actual current project endpoint and ARM ID. A deleted resource or classic hub endpoint cannot be fixed by guessing a new URL.
* **429:** Inspect the saved response/error and its source. Model token limits and upstream API throttling are different. Honor retry-after; avoid nested retry loops or repeatedly increasing quota blindly.
* **Empty/truncated lookup or calculator error:** Correct filter casing and exact SKU/product/meter, follow genuine NextPageLink, narrow the query or refresh expired evidence. Unsupported formulas remain unpriced; there is no zero-price fallback.
* **Private endpoint:** This basic template enables a public authenticated endpoint. Existing isolated projects require a supported VNet/DNS access path and outbound access appropriate for the public Retail API; do not disable their network controls to run this example.

GPT-5 token usage and Code Interpreter sessions can incur charges; managed-agent resources may have additional applicable charges. Capacity 50 is quota allocation, not a fixed-price reservation or guaranteed throughput. Review [Foundry pricing](https://azure.microsoft.com/pricing/details/ai-foundry/) and set an Azure budget before testing.

There is no automatic cleanup. Remove only the deliberately created agent/toolbox versions, uploaded files and project connections you no longer need. For an entirely disposable dedicated installation, review and delete its dedicated resource group in Azure portal; never delete a reused project or unrelated lab infrastructure.

## Official references

* [Azure Retail Prices API](https://learn.microsoft.com/rest/api/cost-management/retail-prices/azure-retail-prices)
* [Foundry OpenAPI tools](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/openapi)
* [Foundry toolboxes](https://learn.microsoft.com/azure/foundry/agents/concepts/toolbox-overview)
* [Native Code Interpreter](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/code-interpreter)
* [Azure AI Projects Python SDK](https://learn.microsoft.com/python/api/overview/azure/ai-projects-readme)
* [Foundry account template](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts), [project template](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts/projects), [model deployment template](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts/deployments)
* [Key Vault operations pricing](https://azure.microsoft.com/pricing/details/key-vault/)
