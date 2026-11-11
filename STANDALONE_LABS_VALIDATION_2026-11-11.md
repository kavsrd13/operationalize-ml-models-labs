# Standalone lab validation — 11 November 2026

## Scope

The active guides for exercises 00–11 now start from a fresh private-repository
clone. The training compute is `course-cpu` in every active job and notebook.
Exercises 08 and 11 each have their own `src/train.py` and `jobs/train-job.yml`.
The GitHub Actions workflow points to exercise 11's copy.

## Checks completed

- Created `course-cpu` in the existing `AzureML/MachineLearn123` workspace in
  subscription `69363a33-89e4-43b9-83d3-9883c3ecabb5`, West US. It is
  `Standard_E4ds_v4`, minimum zero, maximum one; provisioning succeeded.
- The raw Olist data asset `olist-ecommerce-raw:1` was already present.
- Submitted exercise 08's own job definition and training code as
  `calm_rhythm_vkz0b867rk`. The job used `azureml:course-cpu` and completed.
- Registered that job's MLflow output as `olist-freight-cost:3`.
- The revised exercise 11 workflow completed as GitHub Actions run
  [42976817478](https://github.com/kavsrd13/operationalize-ml-models-labs/actions/runs/42976817478).
  Its OIDC sign-in and resource checks passed. It submitted Azure ML job
  `patient_sugar_x127hkz7gw` from exercise 11's own files; the job completed
  on `course-cpu`, and the GitHub run finished green. The temporary GitHub
  secrets/variables, Entra app/service principal, and workspace role were
  deleted afterward.
- Generated all 12 separate HTML pages and the combined index. Checked all
  local HTML links; all targets exist. Python source compiled and `git diff
  --check` found no content errors.
- Windows bootstrap extracted and verified all nine Olist CSVs, installed the
  pinned packages, and registered the **Python (Olist Azure ML)** kernel. Its
  virtual environment path was corrected to `Scripts/python.exe` on Windows.
  The cloud setup was also rerun in the temporary East US workspace; Windows
  Azure CLI invocation was corrected to use the resolved `az.cmd` path. It
  registered `olist-ecommerce-raw:1` and created `course-cpu` successfully.
- Every code cell in exercise 01 and exercise 02 ran locally. Exercise 01
  exported 112,650 freight feature rows. Exercise 02 mapped 99,162 orders and
  found 84 hotspot clusters with its default settings. Its Folium tile source
  was changed to OpenStreetMap after the old tile provider requested an API key.

## Live serving boundary

An earlier exercise 08 freight endpoint was deployed and invoked successfully
in a temporary East US workspace (see `AZURE_ENDPOINT_VALIDATION_2026-11-11.md`).
The new West US attempt created a failed temporary endpoint named
`course-freight-kvs-1111`: Azure returned `SubscriptionNotRegistered` with
provider and subscription both reported as `N/A`. That endpoint was deleted;
the workspace endpoint list was empty afterward. The standalone training and
model-registration steps were verified live; deployment with the newly
registered model was not.

## IMDB and Delhi serving in the teaching subscription

In subscription `42848f6c-f0f7-4143-b9d3-76441ceeda99`, a temporary East US
workspace `mlw-course-endpoint-validate` was created in
`rg-course-endpoint-validate`. It used the generic `course-cpu` cluster.

- Exercise 09: registered `course-imdb-data:1`; training job
  `patient_brake_4pfjzf0nq6` completed; registered
  `course-imdb-sentiment-model:1`; deployment `blue` succeeded at
  `course-imdb-kvs-1111`. The supplied request returned
  `{"sentiment": ["positive", "negative"]}`.
- Exercise 10: registered `course-delhi-train:1` and
  `course-delhi-test:1`; training job `orange_pear_2px33ccf9z` completed;
  registered `course-delhi-climate-model:1`; deployment `blue` succeeded
  at `course-delhi-kvs-1111`. The supplied request returned
  `{"meantemp": [20.06247311088541]}`.

The deployments took several minutes to build their custom inference image.
The two temporary endpoints and the temporary resource group were deleted
after the tests. The permanent `course-cpu` cluster remains only in the
existing `AzureML/MachineLearn123` workspace as requested.

The earlier GitHub Actions workflow also ran end to end (see
`SHARED_COMPUTE_AND_GITHUB_VALIDATION_2026-11-11.md`).
