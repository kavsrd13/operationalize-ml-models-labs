#!/usr/bin/env python3
"""Shared Microsoft Foundry SDK client helpers for Exercise 12."""

from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from openai import OpenAI


@contextmanager
def open_project_client(project_endpoint: str) -> Iterator[OpenAI]:
    """Yield an Entra-authenticated OpenAI client scoped to one Foundry project."""
    with (
        DefaultAzureCredential(
            exclude_managed_identity_credential=True,
            exclude_shared_token_cache_credential=True,
            exclude_visual_studio_code_credential=True,
            exclude_powershell_credential=True,
            exclude_developer_cli_credential=True,
            exclude_interactive_browser_credential=True,
        ) as credential,
        AIProjectClient(endpoint=project_endpoint, credential=credential) as project_client,
        # The OpenAI SDK honors Retry-After headers and retries 429/5xx responses.
        # Five retries preserve the throttling protection from the earlier REST client.
        # AIProjectClient appends /openai/v1. The GA v1 route rejects an
        # api-version query parameter, so do not pass default_query here.
        project_client.get_openai_client(max_retries=5) as openai_client,
    ):
        yield openai_client


def json_data(value: object) -> dict:
    """Convert an OpenAI SDK response model into JSON-serializable data."""
    model_dump = getattr(value, "model_dump", None)
    if not callable(model_dump):
        raise TypeError(f"Expected an SDK response model, received {type(value).__name__}")
    return model_dump(mode="json")
