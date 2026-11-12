# Streamlined exercise collection

This folder contains the custom and adapted demonstrations from the project. The
standard `mslearn-mlops-2` and `mslearn-genaiops` repositories are intentionally
excluded.

## Folder order

1. `01-Olist-EDA-and-Feature-Engineering` explores and prepares freight features.
2. `02-Delivery-Demand-Hotspots` maps and clusters customer-order demand.
3. `03-Freight-Regression-Training` trains freight-cost models locally or as an
   Azure ML command job.
4. `04-Delivery-Time-Pipeline` prepares order-level data and trains through an
   Azure ML pipeline.
5. `05-Freight-AutoML-and-MLflow` compares AutoML and tracked manual models.
6. `06-Late-Delivery-Responsible-AI` trains a classifier and creates an RAI dashboard.
7. `07-Late-Delivery-Hyperparameter-Sweep` tunes the late-delivery classifier.
8. `08-Online-Model-Serving` deploys and tests a freight endpoint and Gradio client.
9. `09-IMDB-Sentiment-Classification` provides local and Azure ML NLP demos.
10. `10-Delhi-Climate-Time-Series` provides local and Azure ML forecasting demos.
11. `11-Automate-Model-Training-GitHub-Actions` runs freight training on a GitHub
    push or manual trigger using OIDC and the shared Azure ML resources.
12. `12-Foundry-Fine-Tuning-GitHub-Actions` validates a versioned MedTriage
    dataset and uses GitHub OIDC to submit a controlled Foundry fine-tuning job.

Shared setup scripts remain in `00-Shared-Setup-and-Data/scripts/` and are
referenced directly by exercises that need them.

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

Create that shared setup when Exercise 03 begins. At the end of each guide from
03 through 09, follow the **Next exercise** section and keep the named resources.
Delete each managed online endpoint immediately after its serving demo. Exercise
10 contains the final shared resource-group deletion and verification commands.

## First-time setup

Start with the local setup. It is enough for exercises 01 and 02 and does not
need an Azure subscription:

```powershell
python .\00-Shared-Setup-and-Data\scripts\bootstrap.py --skip-azure
```

Exercises 03–10 now include the exact Azure setup commands needed to create or
reuse infrastructure in place. Reuse one workspace and `course-cpu` cluster
between those labs. Exercise 12 is independent and uses Azure AI
Services/Foundry instead. Managed online endpoints use separate serving compute
and need globally unique names.

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
