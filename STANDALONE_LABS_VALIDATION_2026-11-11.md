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

The earlier GitHub Actions workflow also ran end to end (see
`SHARED_COMPUTE_AND_GITHUB_VALIDATION_2026-11-11.md`). The explicit IMDB and
Delhi scoring deployments remain unverified live.
