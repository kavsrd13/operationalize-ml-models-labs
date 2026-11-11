# Exercise 07: Tune late-delivery classification

## Goal

Tune logistic regression on pre-April training and April–May validation data.
Keep June–August test labels out of selection.

## Steps

1. Complete exercise 00. Confirm `olist-course-cpu` exists. Open
   `../Azure ML late delivery sweep.ipynb` with the Olist kernel.
2. In notebook step 1 leave `REGISTER_RESOURCES` and `SUBMIT_SWEEP` at
   `False`. Run preparation and inspect the generated train/validation
   `MLTable` and Parquet files.
3. Set `REGISTER_RESOURCES = True` and rerun the registration cell. Verify
   `olist-late-sweep-train:1`, `olist-late-sweep-validation:1`, and
   `olist-sweep-env:2` in the shared workspace.
4. Read `../jobs/sweep-smoke.yml`, `../jobs/sweep.yml`, and the trial script.
   The smoke job uses fixed values; the full sweep has at most eight trials,
   one concurrent trial, and a 300-minute limit.
5. From the collection root, run the smoke job and wait for `Completed`:

   ```powershell
   az ml job create -f .\07-Late-Delivery-Hyperparameter-Sweep\jobs\sweep-smoke.yml `
     -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   az ml job stream -n YOUR_SMOKE_JOB -g YOUR_RESOURCE_GROUP -w YOUR_WORKSPACE
   ```

6. Set `SUBMIT_SWEEP = True` in notebook step 1 and run the sweep submission
   cell once. The job name is saved in ignored `.sweep-run-id.json` to avoid
   duplicate submissions. Alternatively submit `../jobs/sweep.yml` with
   `az ml job create -f` using the same group and workspace.
7. In Studio inspect average precision and late-class precision/recall for
   every trial. Record the selected settings and explain why validation
   results are not a final future-period test.
8. Reset the notebook submission flags to `False` after the run.
