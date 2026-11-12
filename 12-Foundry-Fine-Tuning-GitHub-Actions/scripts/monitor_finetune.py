#!/usr/bin/env python3
"""Monitor one Foundry fine-tuning job to a terminal state and save checkpoints."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from foundry_sdk import json_data, open_project_client


TERMINAL_STATES = {"succeeded", "failed", "cancelled"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", required=True)
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--poll-seconds", type=int, default=60)
    parser.add_argument("--timeout-minutes", type=int, default=330)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    deadline = time.monotonic() + args.timeout_minutes * 60
    previous_status = None
    with open_project_client(args.project_endpoint) as client:
        while True:
            job = client.fine_tuning.jobs.retrieve(args.job_id)
            status = str(job.status).lower()
            if status != previous_status:
                print(f"Fine-tuning status: {status}", flush=True)
                previous_status = status
            if status in TERMINAL_STATES:
                break
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"Job {args.job_id} did not reach a terminal state within {args.timeout_minutes} minutes"
                )
            time.sleep(args.poll_seconds)

        if status == "succeeded":
            checkpoints = [
                json_data(checkpoint)
                for checkpoint in client.fine_tuning.jobs.checkpoints.list(args.job_id)
            ]
        else:
            checkpoints = []

    result = {"job": json_data(job), "checkpoints": checkpoints}
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if status != "succeeded":
        raise SystemExit(f"Fine-tuning job ended with status {status}")
    print(f"Fine-tuned model: {job.fine_tuned_model}")
    print(f"Checkpoints recorded: {len(checkpoints)}")


if __name__ == "__main__":
    main()
