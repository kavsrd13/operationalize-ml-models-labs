"""Shared Foundry connection settings for Exercise 13."""
import os

from azure.ai.projects import AIProjectClient
from azure.identity import AzureCliCredential

AGENT_NAME = os.getenv("ANALYST_AGENT_NAME", "olist-data-analyst")


def project_client():
    endpoint = os.getenv("FOUNDRY_PROJECT_ENDPOINT", "").strip()
    if not endpoint or "/api/projects/" not in endpoint:
        raise ValueError("Set FOUNDRY_PROJECT_ENDPOINT to the full Foundry project endpoint")
    return AIProjectClient(endpoint=endpoint, credential=AzureCliCredential())
