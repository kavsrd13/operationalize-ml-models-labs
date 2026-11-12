#!/usr/bin/env python3
"""Upload versioned JSONL files and submit one Azure OpenAI SFT job using an Entra token."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

import requests


def api_url(endpoint: str, path: str, api_version: str) -> str:
    return f"{endpoint.rstrip('/')}/openai/{path}?api-version={api_version}"


def require_success(response: requests.Response, operation: str) -> dict:
    if response.ok:
        return response.json()
    try:
        detail = response.json()
    except ValueError:
        detail = response.text[:500]
    raise RuntimeError(f"{operation} failed ({response.status_code}): {detail}")


def upload(endpoint: str, token: str, api_version: str, path: Path) -> str:
    with path.open("rb") as content:
        response = requests.post(
            api_url(endpoint, "files", api_version),
            headers={"Authorization": f"Bearer {token}"},
            data={"purpose": "fine-tune"},
            files={"file": (path.name, content, "application/jsonl")},
            timeout=180,
        )
    return require_success(response, f"Upload {path.name}")["id"]


def wait_for_file(endpoint: str, token: str, api_version: str, file_id: str) -> None:
    for _ in range(60):
        response = requests.get(
            api_url(endpoint, f"files/{file_id}", api_version),
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        status = require_success(response, f"Read file {file_id}").get("status")
        if status == "processed":
            return
        if status in {"error", "cancelled"}:
            raise RuntimeError(f"File {file_id} ended with status {status}")
        time.sleep(10)
    raise TimeoutError(f"File {file_id} did not finish processing within 10 minutes")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--token", default=os.environ.get("AZURE_ACCESS_TOKEN"))
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--training-file", type=Path, required=True)
    parser.add_argument("--validation-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--api-version", default="2024-10-21")
    args = parser.parse_args()
    if not args.token:
        raise SystemExit("Provide --token or set AZURE_ACCESS_TOKEN.")
    config = json.loads(args.config.read_text(encoding="utf-8"))
    train_id = upload(args.endpoint, args.token, args.api_version, args.training_file)
    validation_id = upload(args.endpoint, args.token, args.api_version, args.validation_file)
    wait_for_file(args.endpoint, args.token, args.api_version, train_id)
    wait_for_file(args.endpoint, args.token, args.api_version, validation_id)
    payload = {
        "model": config["model"],
        "training_file": train_id,
        "validation_file": validation_id,
        "suffix": config["suffix"],
        "method": {"type": "supervised"},
        "hyperparameters": {
            "n_epochs": config["n_epochs"],
            "learning_rate_multiplier": config["learning_rate_multiplier"],
        },
        "trainingType": config["training_type"],
    }
    response = requests.post(
        api_url(args.endpoint, "fine_tuning/jobs", args.api_version),
        headers={"Authorization": f"Bearer {args.token}", "Content-Type": "application/json"},
        json=payload,
        timeout=90,
    )
    job = require_success(response, "Submit fine-tuning job")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"job": job, "config": config}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"job_id": job.get("id"), "status": job.get("status"), "model": config["model"]}, indent=2))


if __name__ == "__main__":
    main()
