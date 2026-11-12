#!/usr/bin/env python3
"""Upload reviewed data and submit one SFT job through the Microsoft Foundry SDK."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from foundry_sdk import json_data, open_project_client


def build_job_request(config: dict, training_file_id: str, validation_file_id: str) -> dict[str, Any]:
    """Map the course configuration to the official OpenAI fine-tuning SDK shape."""
    return {
        "model": config["model"],
        "training_file": training_file_id,
        "validation_file": validation_file_id,
        "method": {
            "type": config["method"],
            "supervised": {"hyperparameters": config["hyperparameters"]},
        },
        "seed": config["seed"],
        "suffix": config["suffix"],
        "extra_body": {"trainingType": config["training_type"]},
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--training-file", type=Path, required=True)
    parser.add_argument("--validation-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    with open_project_client(args.project_endpoint) as client:
        print(f"Uploading training data: {args.training_file.name}")
        with args.training_file.open("rb") as content:
            training_file = client.files.create(file=content, purpose="fine-tune")

        print(f"Uploading validation data: {args.validation_file.name}")
        with args.validation_file.open("rb") as content:
            validation_file = client.files.create(file=content, purpose="fine-tune")

        print("Waiting for Foundry to process both uploaded files")
        client.files.wait_for_processing(training_file.id)
        client.files.wait_for_processing(validation_file.id)

        request = build_job_request(config, training_file.id, validation_file.id)
        print("Submitting supervised fine-tuning job")
        job = client.fine_tuning.jobs.create(**request)

    output = {
        "job": json_data(job),
        "configuration": config,
        "uploaded_files": {
            "training": training_file.id,
            "validation": validation_file.id,
        },
    }
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"job_id": job.id, "status": job.status, "model": config["model"]}, indent=2))


if __name__ == "__main__":
    main()
