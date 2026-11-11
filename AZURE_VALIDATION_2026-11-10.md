# Azure ML exercise validation — 10 November 2026

This is a record of observed runs in one existing West US Azure ML workspace. The
Microsoft reference repositories were outside scope. The workspace and its earlier
assets were reused. This audit created the `olist-rai-cpu` scale-to-zero cluster,
new job runs and model versions, and one temporary endpoint that was deleted after
its creation failed. No resource group or workspace was created or deleted.

| Exercise | Azure observation | Evidence |
| --- | --- | --- |
| 01–02 | Local exercises only; no new Azure run requested. | Existing source tests passed (8 tests). |
| 03 Freight command job | Completed. Model registered as `olist-freight-cost:2`. | Job `lucid_comb_bx13fnw5kn`. |
| 04 Delivery pipeline | Completed. Both `prep` and `train` child jobs completed. | Pipeline `olden_king_dxfcy5q4n8`. |
| 05 Freight experiments | Ridge and boosting jobs completed. Boosting validation MAE was 5.3126 BRL versus Ridge 5.6263 BRL, so boosting was selected. AutoML completed five trials. The selected model registered as `olist-freight-regression-exp:2`; held-out evaluation completed on 21,418 items with MAE 5.6747 BRL. | Ridge `loyal_jewel_pcm3vmqbf6`, boosting `khaki_animal_n6mpkc4gww`, AutoML `sleepy_drain_3q6rx632y7`, evaluation `willing_orange_2rqyd722zl`. |
| 06 Responsible AI | Classifier training completed and model registered as `olist-late-delivery-rai:2`. The dashboard pipeline completed all four components: constructor, error analysis, explanation, and gather. | Training `mango_stone_1j3hqm16z7`, dashboard `great_forest_k84ydhxx5l`. |
| 07 Sweep | Fixed trial completed. The bounded sweep completed all eight child trials and the parent job. The CLI sweep YAML required moving `inputs` to the sweep root. | Smoke `mango_queen_4b5f99v83c`, sweep `shy_nutmeg_4y4yfc4168`. |
| 08 Online serving | The new model registered and the endpoint create request reached Azure, but the endpoint failed with `SubscriptionNotRegistered` and an unspecified provider (`N/A`). The common ML, Network, Compute, Container Registry, Container Instance, Storage, and Managed Identity providers showed `Registered`. The failed temporary endpoint was deleted. No deployment, invocation, or Gradio end-to-end result is established. | Temporary endpoint `course-olist-freight-kd1110`; activity log showed `Microsoft.MachineLearningServices/workspaces/onlineEndpoints/write` failed. |
| 09 IMDB sentiment | First cloud run failed because an unquoted CSV path contained a space. Corrected run completed with test accuracy 0.8995; model registered as `course-imdb-sentiment-model:1`. Endpoint serving remains subject to the same exercise 08 service block. | Failed `lucid_boniato_kydsf6wd46`, completed `loyal_corn_k3wf3b1jz9`. |
| 10 Delhi climate | First cloud run hit an MLflow 3 tracking API 404; second run required `skops`. Saving a cloudpickle MLflow folder under job outputs fixed both. Final run completed with test MAE 1.4031 °C and RMSE 1.8230 °C; model registered as `course-delhi-climate-model:1`. Endpoint serving remains subject to the exercise 08 service block. | Failed `strong_kite_5c11y44xl0`, `ivory_animal_tg48k8812r`; completed `shy_guava_n81s376rtl`. |

The failed temporary endpoint was confirmed absent from the workspace endpoint list.
The local test environment was not the pinned teaching environment. These Azure jobs
are the primary evidence for cloud training. A completed Azure job does not validate
the Gradio client, endpoint HTTP contract, or every interactive notebook cell.

## Resource naming for clients

Use one resource group and Azure ML workspace across all cloud exercises. The shared
Olist data asset is `olist-ecommerce-raw:1`; exercises 06–07 share `olist-rai-cpu`,
which has `min_instances: 0`, and exercise 07 uses `olist-sweep-env:2`. Job experiment
names identify the exercise. Register each model under its own name. Give endpoints
globally unique names, for example `course-olist-<initials>`, and delete only the
endpoint created for the demo.

## Remaining validation

1. Resolve Azure's unspecified provider error for managed online endpoints, then
   validate deployment, valid and malformed invocations, and the Gradio client.
