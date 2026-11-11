"""Run the notebook-style Python SDK deployment as a script.

This keeps the CLI-based deployment intact while providing a reproducible, non-notebook
execution path for CI or automation.

Docs reference:
https://learn.microsoft.com/azure/machine-learning/how-to-deploy-mlflow-models-online-endpoints?view=azureml-api-2
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import requests
from azure.ai.ml import MLClient
from azure.ai.ml.constants import AssetTypes
from azure.ai.ml.entities import (
    CodeConfiguration,
    Environment,
    ManagedOnlineDeployment,
    ManagedOnlineEndpoint,
    Model,
)
from azure.identity import AzureCliCredential


def main() -> int:
    # Set these for your own workspace before running the optional SDK demo.
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    resource_group = os.environ["AZURE_RESOURCE_GROUP"]
    workspace_name = os.environ["AZURE_ML_WORKSPACE"]

    # Recreate the original endpoint name, but via Python SDK.
    endpoint_name = os.environ["FREIGHT_ENDPOINT_NAME"]

    # Register a separate model name from local MLflow artifacts.
    model_name = "olist-freight-cost-notebook"
    deployment_name = "blue"

    here = Path(__file__).resolve().parent
    mlflow_model_dir = here / "mlflow-model" / "olist-freight-cost" / "model"
    deploy_dir = here / "deploy"
    sample_request_file = here / "sample-request.json"

    if not (mlflow_model_dir / "MLmodel").exists():
        raise FileNotFoundError(f"MLmodel not found at {mlflow_model_dir}")
    if not sample_request_file.exists():
        raise FileNotFoundError(f"Missing sample request: {sample_request_file}")

    ml_client = MLClient(AzureCliCredential(), subscription_id, resource_group, workspace_name)

    print("Registering model from local MLflow artifacts...")
    model = ml_client.models.create_or_update(
        Model(
            name=model_name,
            path=str(mlflow_model_dir),
            type=AssetTypes.MLFLOW_MODEL,
            description="Olist freight-cost model (registered via Python SDK notebook flow)",
        )
    )
    print(f"Registered: {model.name}:{model.version}")

    print("Creating endpoint...")
    endpoint = ManagedOnlineEndpoint(
        name=endpoint_name,
        description="Freight cost endpoint (created via Python SDK)",
        auth_mode="key",
        tags={"model": model_name},
    )
    endpoint = ml_client.online_endpoints.begin_create_or_update(endpoint).result()
    print("Endpoint provisioning_state:", endpoint.provisioning_state)

    print("Creating environment...")
    environment = Environment(
        name="olist-freight-inference-notebook",
        image="mcr.microsoft.com/azureml/minimal-ubuntu22.04-py39-cpu-inference:latest",
        conda_file=str(deploy_dir / "conda.yaml"),
    )
    environment = ml_client.environments.create_or_update(environment)
    print("Environment:", environment.name, environment.version)

    print('Creating deployment "blue" (first run can take ~10-20 minutes)...')
    deployment = ManagedOnlineDeployment(
        name=deployment_name,
        endpoint_name=endpoint_name,
        model=model,
        environment=environment,
        code_configuration=CodeConfiguration(code=str(deploy_dir), scoring_script="score.py"),
        instance_type="Standard_D2ds_v5",
        instance_count=1,
    )
    deployment = ml_client.online_deployments.begin_create_or_update(deployment).result()
    print("Deployment provisioning_state:", deployment.provisioning_state)

    print("Routing 100% traffic to blue...")
    endpoint = ml_client.online_endpoints.get(endpoint_name)
    endpoint.traffic = {deployment_name: 100}
    endpoint = ml_client.online_endpoints.begin_create_or_update(endpoint).result()
    print("Scoring URI:", endpoint.scoring_uri)

    print("Invoking endpoint...")
    keys = ml_client.online_endpoints.get_keys(endpoint_name)
    payload = json.loads(sample_request_file.read_text(encoding="utf-8"))
    resp = requests.post(
        endpoint.scoring_uri,
        json=payload,
        headers={"Authorization": f"Bearer {keys.primary_key}"},
        timeout=30,
    )
    print("HTTP", resp.status_code)
    print(resp.json())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
