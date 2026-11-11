# Delivery-Time Model — Azure ML pipeline (data processing + training)

This is supplemental source material with older example workspace names. Use
`../../Instruction/README.md` for the current student commands.

Predicts **how many days an Olist order will take from purchase to delivery**, using only
information known when the customer checks out. Training runs as a two-step **Azure ML
pipeline** on the shared `course-cpu` cluster, is tracked with **MLflow**, and the model is **registered**
as `olist-delivery-time`.

```
olist-ecommerce-raw:1 ──► [ prep ] ──orders_features.csv──► [ train ] ──► trained_model ──► olist-delivery-time:<n>
```

## Files

| File | What it does |
|---|---|
| `src/prep/prep.py` | **Step 1, data processing.** Keeps delivered orders, computes the target `delivery_days`, combines the items of each order, adds the seller→customer distance and calendar features. Writes `orders_features.csv` (one row per order). |
| `src/train/train.py` | **Step 2, training.** Time-based split, two benchmarks and three models, MLflow metrics and plots, saves the kept model in MLflow format. |
| `pipelines/delivery-time-pipeline.yml` | The Azure ML pipeline that wires prep → train on shared compute |
| `scripts/submit-pipeline.ps1` | Submits the pipeline and waits for it to finish (saves the job name in `.last-pipeline-job`) |
| `scripts/register-model.ps1` | Registers the pipeline output as `olist-delivery-time:<version>` |

## The ML problem

- **Target:** `delivery_days`, the number of days from purchase to delivery. The median is
  10.2 days, the mean 12.6, the maximum over 200.
- **Features**, all known at checkout:

  | Feature | Meaning |
  |---|---|
  | `distance_km` | Distance from seller to customer |
  | `same_state` | Seller and customer in the same state |
  | `seller_state`, `customer_state` | The two states |
  | `promised_days` | The delivery estimate Olist showed the customer |
  | `n_items`, `n_sellers` | Items and sellers in the order |
  | `total_price`, `total_freight` | Order value and shipping cost |
  | `total_weight_g`, `total_volume_cm3` | Order weight and volume |
  | `product_category` | Category of the most expensive item |
  | `purchase_month`, `purchase_weekday`, `purchase_hour` | When the order was placed |

- **Time-based split:** train on orders before 2018-06-01 (77,867 orders), test on
  June–August 2018 (18,603 orders).

## Results (Azure ML pipeline run; test set June–August 2018)

| Model | MAE (days) | Within ±3 days | Orders arriving after the predicted date |
|---|---|---|---|
| Baseline (training median) | 4.95 | 30.3% | 22.2% |
| **Olist's own promise** | 12.72 | 11.2% | 5.5% |
| Linear (ridge, log target) | 4.21 | 44.8% | 22.6% |
| **Gradient boosting, absolute error (kept)** | **3.46** | **54.9%** | 31.2% |
| Gradient boosting P90 (safe promise) | 9.13 | 9.6% | 4.7% |

The most important feature by far is `promised_days`, Olist's own estimate.
`customer_state` gets a *negative* importance on the test set: the regional patterns
the model learned in 2017 no longer held in mid-2018. That's another face of the drift below.

What students should take away:

1. **Expected time vs safe promise.**
   - The kept model predicts the *typical* delivery time, within ±3 days for 55% of orders.
     It's an honest estimate, so by design many orders arrive after it.
   - The P90 model predicts a date that 90% of orders beat. It's as reliable as Olist's own
     promise (about 5% late), but its promises are on average **3.6 days shorter**.
   - Which one to show customers is a business decision, not a modelling decision.
2. **Data drift.** Average delivery fell from about 16 days (Feb–Mar 2018) to about 8 days
   (August 2018). A model trained on the slower past over-predicts.
   `plots/monthly_drift.png` shows it, and it's a reason to retrain regularly.

## Run it

```powershell
cd project-2-delivery-time\delivery-time-model

# Optional local test (about 1 minute, free)
$env:MLFLOW_TRACKING_URI = "sqlite:///local-run/mlflow.db"
python src\prep\prep.py   --raw_data "..\..\Ecommerce Dataset" --output_data local-run\features
python src\train\train.py --features local-run\features --model_output local-run\model

# In Azure ML (shared scale-to-zero cluster)
.\scripts\submit-pipeline.ps1 -ResourceGroup rg-olist-ml-dev -Workspace mlw-olist-dev
.\scripts\register-model.ps1  -ResourceGroup rg-olist-ml-dev -Workspace mlw-olist-dev
```

The pipeline needs the workspace and the data asset `olist-ecommerce-raw:1`. If you haven't
created them yet, run `..\azure-ml-infra\scripts\00` to `04` first; see the project README.

## What to look at in Azure ML studio

- **Jobs → olist-delivery-time → your pipeline:** the graph of the two steps. Click a step to
  see its logs, metrics and outputs.
- **prep step → Metrics:** row count and average delivery time.
- **train step → Metrics:** `boosting_mae_days`, `olist_promise_mae_days`,
  `boosting_p90_late_vs_prediction`, and so on.
- **train step → Images:** `predicted_vs_actual.png`, `feature_importance.png`, `monthly_drift.png`.
- **Data / pipeline outputs:** the `features` folder written by prep is stored and can be reused.

## Exercises

1. Add `--max-iter 300 --learning-rate 0.1` to the train command in the pipeline YAML,
   resubmit, and compare the runs.
2. Move the test window to start on 2018-04-01. How does the MAE change, and why (drift)?
3. Add a feature `seller_avg_days`, the seller's average delivery time in the training period.
   How do you avoid data leakage when you build it?
4. Turn it into classification: predict whether the order arrives after `promised_days`.
