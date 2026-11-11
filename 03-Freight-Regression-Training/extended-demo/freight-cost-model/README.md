# Module 2 — Olist Freight-Cost Model (Azure ML training job)

This is supplemental source material with older example workspace names. Use
`../../Instruction/README.md` for the current student commands.

This module predicts the **shipping cost** (`freight_value`, in Brazilian reais) of an Olist
order item. It trains the model as an **Azure ML command job** on the shared `course-cpu` cluster, tracks
the run with **MLflow**, and **registers** the model in the workspace.

It builds on Module 1 (`../azure-ml-infra`). That module created the workspace
`mlw-olist-dev` and the data asset `olist-ecommerce-raw:1`.

## Files

| File | What it does |
|---|---|
| `src/train.py` | Joins 7 Olist tables and builds features known at checkout time. It trains 3 models and logs metrics, plots and the model to MLflow. |
| `jobs/train-job.yml` | The Azure ML job: code, data input, curated environment, shared compute |
| `scripts/submit-training.ps1` | Submits the job and streams its logs |
| `scripts/register-model.ps1` | Registers the trained model as `olist-freight-cost:<version>` (uses the last submitted job by default) |
| `deploy/` | Online endpoint: `endpoint.yml`, `deployment.yml`, `score.py`, `conda.yaml`, `sample-request.json` |
| `scripts/deploy-endpoint.ps1`, `test-endpoint.ps1`, `delete-endpoint.ps1` | Deploy, call and remove the endpoint |
| `scripts/create-app-env.ps1` | Writes `app/.env` with *your* endpoint URL and key, fetched live (the key is never printed) |
| `app/app.py` | Gradio web app to test the endpoint from a browser |

> **No credentials are stored in this project.** Each student creates their own endpoint, and
> the key is fetched live with their own Azure login. `app/.env` is ignored by git.

## The ML problem

- **Target:** `freight_value` per order item. The median is R$16 and the spread is large
  (max R$410), so the model learns `log(1 + freight)` and converts back to reais.
- **Features:** all known when the customer checks out.
  - seller→customer **distance** (haversine, from zip-code coordinates)
  - same state or not
  - product **weight**, dimensions and volume
  - **price** and product category
  - seller and customer state
  - number of items in the order, and from the same seller
  - purchase month
- **Split by time, not at random:** train on orders before **2018-06-01** (91k items), test on
  June–August 2018 (21k items). This mimics predicting the future from the past.
- **Models compared:**

| Model | Idea |
|---|---|
| Baseline | Always predict the training median |
| Linear (ridge) | One-hot categories + scaled numbers |
| **Gradient boosting** | `HistGradientBoostingRegressor` with native categorical splits. **This is the model that is kept.** |

## Run it

```powershell
cd freight-cost-model

# 1. Train in the cloud (shared course-cpu cluster; minimum zero nodes)
.\scripts\submit-training.ps1

# 2. Check metrics in studio (Jobs -> olist-freight-cost), then register the model
.\scripts\register-model.ps1 -JobName <job-name-printed-by-step-1>
```

Run locally first (free, about 1 minute):

```powershell
$env:MLFLOW_TRACKING_URI = "sqlite:///mlflow.db"
python src/train.py --data "..\..\Ecommerce Dataset"
```

## What to look at in Azure ML studio

- **Jobs → olist-freight-cost → your run → Metrics:** `baseline_mae`, `linear_mae`,
  `boosting_mae`, `mae_improvement_vs_baseline`, and `*_within_5_brl` (the share of
  predictions within R$5 of the real freight)
- **Images:** `plots/predicted_vs_actual.png` and `plots/feature_importance.png`
- **Outputs + logs → outputs/model/:** the MLflow model (MLmodel file, conda env, input
  signature) and `outputs/metrics.json`
- **Models → olist-freight-cost:** the registered version, with a link back to the job,
  code and data that produced it (lineage)

## Deploy and call the endpoint

Choose your own endpoint name (3–32 characters, unique within the Azure region), for example
`freight-<yourproject>`:

```powershell
$ep = 'freight-olistanna'            # <- your endpoint name
$rg = 'rg-olistanna-ml-dev'; $ws = 'mlw-olistanna-dev'

.\scripts\deploy-endpoint.ps1 -EndpointName $ep -ResourceGroup $rg -Workspace $ws   # ~15-20 min first time
.\scripts\test-endpoint.ps1   -EndpointName $ep -ResourceGroup $rg -Workspace $ws   # calls it with deploy/sample-request.json
.\scripts\delete-endpoint.ps1 -EndpointName $ep -ResourceGroup $rg -Workspace $ws   # STOP THE COST when you are done
```

| File | Role |
|---|---|
| `deploy/endpoint.yml` | The stable HTTPS URL + key authentication |
| `deploy/deployment.yml` | The "blue" deployment: model version, VM size (`Standard_D2ds_v5`), environment |
| `deploy/score.py` | `init()` loads the model once; `run()` validates the JSON and predicts |
| `deploy/conda.yaml` | Python 3.10 + scikit-learn 1.5.2, the same versions used for training |
| `deploy/sample-request.json` | Three example order items |

**Request:** `POST <scoring URL>` with headers `Authorization: Bearer <key>` and
`Content-Type: application/json`:

```json
{ "input_data": [ {
    "seller_state": "SP", "customer_state": "RJ", "product_category": "furniture_decor",
    "price": 249.0, "product_weight_g": 9500,
    "product_length_cm": 60, "product_height_cm": 40, "product_width_cm": 40,
    "distance_km": 360
} ] }
```

**Response:** `{"freight_value_brl": [58.9], "model": "olist-freight-cost"}`

Required fields: `seller_state`, `customer_state`, `price`, `product_weight_g`,
`product_length_cm`, `product_height_cm`, `product_width_cm`, `distance_km`.

The service fills in these optional fields if you leave them out:

| Field | Default |
|---|---|
| `product_category` | `unknown` |
| `volume_cm3` | Product of the three dimensions |
| `same_state` | Derived from the two states |
| `items_in_order` | 1 |
| `items_from_seller` | 1 |
| `purchase_month` | Current month |

**Get the URL and key of your endpoint:**
```powershell
az ml online-endpoint show -n $ep -g $rg -w $ws --query scoring_uri -o tsv
az ml online-endpoint get-credentials -n $ep -g $rg -w $ws
```

**Python client** (reads the values from environment variables, never from code):
```python
import json, os, urllib.request
url = os.environ["FREIGHT_ENDPOINT_URL"]; key = os.environ["FREIGHT_ENDPOINT_KEY"]
body = json.dumps({"input_data": [{"seller_state": "SP", "customer_state": "RJ", "price": 249.0,
        "product_weight_g": 9500, "product_length_cm": 60, "product_height_cm": 40,
        "product_width_cm": 40, "distance_km": 360}]}).encode()
req = urllib.request.Request(url, body, {"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
print(json.loads(urllib.request.urlopen(req).read()))
```

> Keep the key secret: anyone with it can call the endpoint. If it leaks, regenerate it with
> `az ml online-endpoint regenerate-keys -n $ep --key-type primary -g $rg -w $ws`.

## Test it in a browser (Gradio app)

```powershell
pip install -r app\requirements.txt
.\scripts\create-app-env.ps1 -EndpointName $ep -ResourceGroup $rg -Workspace $ws   # writes app\.env
python app\app.py                                                                  # open http://127.0.0.1:7860
```

The app pre-fills the distance from the two states you choose. It shows the predicted
shipping cost and the exact JSON request and response, and it explains errors such as a
wrong key (401/403) or a wrong URL (404).

## Exercises

1. Resubmit with `-LearningRate 0.1 -MaxIter 300` and compare the two runs side by side in studio.
2. Remove `distance_km` from `NUMERIC` in `train.py`. How much worse does the MAE get?
3. Why would a **random** train/test split give an over-optimistic MAE here?
4. Which feature would be leakage if you added it? Hint: anything known only after delivery.
5. Train a second model version and create a `green` deployment next to `blue`. Send it 10%
   of the traffic (`az ml online-endpoint update --traffic "blue=90 green=10"`). This is a
   safe blue/green release.
