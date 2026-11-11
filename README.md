# Streamlined exercise collection

This folder contains the custom and adapted demonstrations from the project. The
standard `mslearn-mlops-2` and `mslearn-genaiops` repositories are intentionally
excluded.

## Folder order

1. `00-Shared-Setup-and-Data` prepares the common Python environment, Azure ML
   workspace configuration, Olist data asset, and optional infrastructure.
2. `01-Olist-EDA-and-Feature-Engineering` explores and prepares freight features.
3. `02-Delivery-Demand-Hotspots` maps and clusters customer-order demand.
4. `03-Freight-Regression-Training` trains freight-cost models locally or as an
   Azure ML command job.
5. `04-Delivery-Time-Pipeline` prepares order-level data and trains through an
   Azure ML pipeline.
6. `05-Freight-AutoML-and-MLflow` compares AutoML and tracked manual models.
7. `06-Late-Delivery-Responsible-AI` trains a classifier and creates an RAI dashboard.
8. `07-Late-Delivery-Hyperparameter-Sweep` tunes the late-delivery classifier.
9. `08-Online-Model-Serving` deploys and tests a freight endpoint and Gradio client.
10. `09-IMDB-Sentiment-Classification` provides local and Azure ML NLP demos.
11. `10-Delhi-Climate-Time-Series` provides local and Azure ML forecasting demos.
12. `11-Automate-Model-Training-GitHub-Actions` runs freight training on a GitHub
    push or manual trigger using OIDC and the shared Azure ML resources.

Open `index.html` for the complete offline student guide. Every exercise also has
its own `Instruction/index.html` and editable `Instruction/README.md`. Rebuild the
HTML after editing instructions with `python scripts/build_instructions.py`.

## Shared Olist data

The Olist archive is stored once at `datasets/olist/Ecommerce Dataset.zip` to avoid
copying 42 MB into every exercise. The setup script extracts or verifies the nine CSVs.
All Olist notebooks locate this shared folder by walking up to this collection root.

Use one Azure ML workspace and resource group for all cloud exercises. Keep the
`olist-ecommerce-raw:1` data asset, the `olist-course-cpu` scale-to-zero cluster, and the
`olist-sweep-env:2` environment between labs. Each job has its own experiment name;
register models with exercise-specific names and use unique endpoint names so students
in a shared workspace do not collide.

## First-time setup

From this folder, run:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py `
  --subscription YOUR_SUBSCRIPTION_ID `
  --resource-group YOUR_RESOURCE_GROUP `
  --workspace YOUR_WORKSPACE --create-cluster
```

The shared cluster is created once and reused by exercises 03–07 and 09–11.
For local-only exercises 01 and 02, run bootstrap with `--skip-azure` instead.
Each student instruction names its additional prepared data assets. Managed online
endpoints use separate serving compute and need globally unique names.

## Validation boundary

The numbered training and pipeline labs have recorded Azure results. Freight online
serving was tested; IMDB and Delhi online serving still need live verification of
their updated scoring scripts. Cloud commands create billable resources and should
be run deliberately in the learner's own workspace.
See `AZURE_VALIDATION_2026-11-10.md` and
`AZURE_ENDPOINT_VALIDATION_2026-11-11.md` for earlier live results and cleanup.
See `SHARED_COMPUTE_AND_GITHUB_VALIDATION_2026-11-11.md` for the latest shared
compute training run and GitHub workflow publication check.
The newer shared-compute YAML, named IMDB/Delhi data assets, GitHub OIDC workflow,
and explicit IMDB/Delhi serving scripts still require live validation in the
client's workspace before being described as cloud-verified.
