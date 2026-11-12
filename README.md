# Streamlined exercise collection

This folder contains the custom and adapted demonstrations from the project. The
standard `mslearn-mlops-2` and `mslearn-genaiops` repositories are intentionally
excluded.

## Folder order

1. `01-Olist-EDA-and-Feature-Engineering` explores and prepares freight features.
2. `02-Delivery-Demand-Hotspots` maps and clusters customer-order demand.
3. `00-Shared-Setup-and-Data` sets up Python and shared data first, then Azure
   workspace resources right before the first cloud lab.
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
13. `12-Foundry-Fine-Tuning-GitHub-Actions` validates a versioned MedTriage
    dataset and uses GitHub OIDC to submit a controlled Foundry fine-tuning job.

Open `index.html` for the complete offline student guide. Every exercise also has
its own `Instruction/index.html` and editable `Instruction/README.md`. Each guide
starts with a fresh clone, then lists clickable links to that lab's actual code.
Exercises 08 and 11 contain their own freight training script and job definition,
so neither requires exercise 03 to have been run. Rebuild the HTML after editing
instructions with `python scripts/build_instructions.py`.

## Shared Olist data

The Olist archive is stored once at `datasets/olist/Ecommerce Dataset.zip` to avoid
copying 42 MB into every exercise. The setup script extracts or verifies the nine CSVs.
All Olist notebooks locate this shared folder by walking up to this collection root.

Use one Azure ML workspace and resource group for all cloud exercises. Keep the
`olist-ecommerce-raw:1` data asset, the `course-cpu` scale-to-zero cluster, and the
`olist-sweep-env:2` environment between labs. Each job has its own experiment name;
register models with exercise-specific names and use unique endpoint names so students
in a shared workspace do not collide.

## First-time setup

Start with the local setup. It is enough for exercises 01 and 02 and does not
need an Azure subscription:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
```

When you reach a cloud exercise (03–11), create or choose one Azure ML workspace
and run bootstrap with its subscription, resource group, and workspace names plus
`--create-cluster`. This registers the shared data asset and creates `course-cpu`
once; reuse those resources between labs. See Exercise 00 for the exact commands.
Exercise 12 is independent and uses Azure AI Services/Foundry instead. Each lab
lists any additional prepared data assets. Managed online endpoints use separate
serving compute and need globally unique names.

## Validation boundary

The numbered training and pipeline labs have recorded Azure results. Freight,
IMDB, and Delhi online serving have passed live sample requests in East US.
Cloud commands create billable resources and should
be run deliberately in the learner's own workspace.
See `AZURE_VALIDATION_2026-11-10.md` and
`AZURE_ENDPOINT_VALIDATION_2026-11-11.md` for earlier live results and cleanup.
See `SHARED_COMPUTE_AND_GITHUB_VALIDATION_2026-11-11.md` for the latest shared
compute training run and successful GitHub OIDC automation test.
Exercise 03's earlier shared-compute job and exercise 11's earlier workflow were
live-tested. The generic `course-cpu` cluster is provisioned, and exercise 08's
standalone training and model registration completed in Azure. A new West US
endpoint attempt failed with a subscription registration error and was removed.
The revised exercise 11 workflow completed a live GitHub Actions → Azure ML
training run on `course-cpu`. See `STANDALONE_LABS_VALIDATION_2026-11-11.md`
for the current checks.
The named IMDB/Delhi assets, training jobs, and explicit scoring scripts were
live-tested in a temporary workspace in the teaching subscription. The newer
shared-compute settings for 04–07 still need a fresh run before being described
as verified in every learner workspace.
