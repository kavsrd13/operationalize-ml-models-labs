# Exercise 05: Compare AutoML and MLflow experiments

## Goal

Prepare chronological freight data, compare bounded AutoML with tracked Ridge
and boosting jobs, select on validation data, and use the held-out test once.

## Steps

1. Complete exercise 00. Confirm `olist-course-cpu` exists. Open
   `../Olist freight Azure ML experiments.ipynb` with **Python (Olist Azure ML)**.
2. In notebook step 1 leave `UPLOAD_DATA`, `SUBMIT_JOBS`, and
   `SUBMIT_EVALUATION` set to `False`. Run the setup and preparation cells.
3. Inspect the three `data/{train,validation,test}` folders. Each must have
   `orders.csv` and `MLTable`; dates must be chronological. The test set is
   reserved until a validation winner is chosen.
4. Set `UPLOAD_DATA = True` and rerun the registration cell. Verify the named
   assets `olist-freight-train:1`, `olist-freight-validation:1`, and
   `olist-freight-test:1` in Studio. Existing version 1 assets are reused.
5. Review `../jobs/automl-regression.yml` (five trials, one concurrent,
   90-minute total), `../jobs/track-mlflow.yml`, and `../src/train.py`.
   All jobs use `olist-course-cpu`.
6. Set `SUBMIT_JOBS = True`, rerun notebook steps 6–8, and record the AutoML,
   Ridge, and boosting job IDs saved in ignored `.freight-run-ids.json`.
7. Wait until all three jobs show `Completed`. In Studio inspect validation
   MAE, baseline, plots, MLflow parameters, and model outputs. Choose either
   Ridge or boosting using validation evidence; do not choose on test data.
8. In the notebook's final evaluation cell set `selected_algorithm` to the
   chosen manual model and `SUBMIT_EVALUATION = True`. This registers the
   selected model and submits `../jobs/evaluate.yml` against
   `olist-freight-test:1` once.
9. Wait for the evaluation job to complete. Record held-out MAE/RMSE and
   compare them to validation. If the test result differs, discuss time drift.
10. Reset the three submission flags to `False` in your saved notebook.

Do not delete the shared cluster or assets while later exercises need them.
