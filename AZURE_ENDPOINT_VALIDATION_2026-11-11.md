# Endpoint validation and cleanup — 11 November 2026

The three trained models were copied into one temporary East US Azure ML workspace in
the teaching subscription. This isolated the earlier subscription's endpoint creation
error. The temporary resource group was `rg-course-endpoint-validation-1111`.

| Lab | Live result | Code change |
| --- | --- | --- |
| 08 Freight | Endpoint and deployment succeeded. The three-row sample returned freight predictions of 10.25, 60.02, and 31.6 BRL. An invalid batch element returned `Each input item must be an object`. The temporary endpoint was deleted. | Added a checked-in invalid request fixture. |
| 09 IMDB | Endpoint creation succeeded. The original no-code MLflow deployment failed its liveness probe with HTTP 502. Container logs showed `ModuleNotFoundError: No module named 'azureml'` in Azure's generated scoring script. The corrected explicit scoring deployment was started but not verified before cleanup. | Changed the VM size to `Standard_D2ds_v5`; added `deploy/score.py` and a pinned inference environment; fixed the interactive notebook's endpoint API call. |
| 10 Delhi | Endpoint creation succeeded. The original no-code MLflow deployment failed health checks with HTTP 502. The corrected explicit scoring deployment was not submitted before cleanup. | Changed the VM size to `Standard_D2ds_v5`; added `deploy/score.py` and a pinned inference environment. |

The first workspace creation linked to a nonexistent Container Registry. A real Basic
registry was created and attached to the temporary workspace. The freight deployment
then succeeded on retry. `Standard_DS3_v2` was also rejected for online inference quota,
so the IMDB and Delhi deployment files use the smaller VM family that the freight lab
used successfully.

The explicit IMDB and Delhi scoring scripts have not passed a live deployment and
invocation test. Those two serving labs are still unverified. Training and model
registration for both were verified in the earlier Azure validation report.

## Cleanup scope

The dedicated temporary resource group in the teaching subscription was deleted after
the user asked to remove resources no longer needed. Azure returned `false` for group
existence after deletion completed. This removed its endpoints, workspace, registry,
model copies, and supporting resources. Local downloaded model copies were also removed.

In the earlier Azure ML workspace, the validation-created `olist-rai-cpu` cluster was
deleted. Five model versions created by the earlier validation were archived because
the Azure ML CLI exposes archive but no delete operation for models. The workspace and
its pre-existing storage, Key Vault, monitoring, registries, and compute instance were
preserved.
