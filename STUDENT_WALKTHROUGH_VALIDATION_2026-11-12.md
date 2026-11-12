# Student walkthrough validation — 12 November 2026

## Test boundary

Testing started from a fresh clone of GitHub `main` at commit `7dc0dcb`. Commands
were followed in learner order. Local work used Python 3.11.6. Live Azure ML
testing used subscription `69363a33-89e4-43b9-83d3-9883c3ecabb5` and a temporary
Central US resource group created only for Exercise 03.

## Completed student checks

| Exercise | Result | Evidence |
| --- | --- | --- |
| 00 shared setup | Passed | Bootstrap created `.venv`, verified all nine CSV files, reported 99,441 order rows, and `pip check` reported no broken requirements. |
| 01 Olist EDA | Passed | Every notebook cell executed; `outputs/olist_freight_features.csv` was produced. |
| 02 delivery hotspots | Passed | Every notebook cell executed; the rendered map and clustering outputs were produced in the executed notebook. |
| 03 freight training — local | Passed with a warning | Every notebook cell executed. Windows Joblib printed a harmless `resource_tracker` message after parallel work, but notebook execution exited successfully. |
| 03 freight training — Azure ML | Passed | Job `silver_shelf_51530lb0bj` reached `Completed`. Downloaded evidence contained `metrics.json`, plots, and a valid MLflow model folder. |

Exercise 03 Azure metrics were:

- Median baseline MAE: `9.7709` BRL.
- Ridge MAE: `6.1179` BRL.
- Gradient boosting MAE: `5.4856` BRL.

Azure CLI `az ml job stream` remained open after the job completed and then
reported a Base64 `Incorrect padding` error when interrupted. `az ml job show`
correctly reported `Completed`, and `az ml job download --all` retrieved all
evidence. The guides now use status checks as the reliable path and describe
streaming as optional.

The temporary resource group `rg-oml-lab03-1112` was deleted after validation.
`az group exists` returned `false`.

## Instruction changes resulting from the walkthrough

- Bootstrap now displays dependency installation and long Azure creation progress.
- Exercises 03–09 end with an explicit **Next exercise** handoff.
- Shared workspace, asset, compute, environment, and endpoint lifecycle is stated explicitly.
- Exercise 08 is documented as independent of the Exercise 03 model run.
- Exercise 10 owns final shared-resource-group cleanup and deletion verification.
- Generated HTML next-step links open the next rendered exercise page.

## Not yet revalidated in this walkthrough

Exercises 04–12 were not rerun live after these documentation changes. Earlier
validation reports remain useful evidence, but they are not a substitute for a
fresh learner walkthrough in the current subscription and repository revision.
