# Exercise 04: Train through an Azure ML pipeline

## Goal

Prepare order-level checkout features in one step, pass them to a training step,
and inspect the model produced by the pipeline.

## Steps

1. Complete exercise 00 and set `$RG` and `$WS` in PowerShell as shown there.
   Confirm `olist-ecommerce-raw:1` and `olist-course-cpu` exist.
2. Open `../delivery-time-local.ipynb` with the Olist kernel. Run every cell and
   identify which fields are known at checkout.
3. Read `../src/prep/prep.py` and `../src/train/train.py`. Trace the feature
   folder from preparation into training.
4. Read `../pipelines/delivery-time-pipeline.yml`. Find its raw input,
   default compute, `prep` output, `train` input, and `trained_model` output.
5. Preview and submit the pipeline from the collection root:

   ```powershell
   python .\00-Shared-Setup-and-Data\scripts\submit.py delivery --dry-run
   python .\00-Shared-Setup-and-Data\scripts\submit.py delivery
   ```

6. Copy the pipeline job name, then wait and check it:

   ```powershell
   az ml job stream -n YOUR_PIPELINE_JOB -g $RG -w $WS
   az ml job show -n YOUR_PIPELINE_JOB -g $RG -w $WS --query status -o tsv
   ```

7. In Studio inspect both child jobs, their logs, metrics, and `trained_model`.
   Explain why `train` cannot start before `prep` finishes.

The `../extended-demo/` folder is supplemental source material with older paths.
