#!/usr/bin/env python3
"""Run a small, repeatable base-model baseline against the held-out validation split."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import json
import os
from pathlib import Path
import time

import requests

EXPECTED_KEYS = {"urgency", "department", "reason", "next_step"}
MAX_RATE_LIMIT_RETRIES = 5
MAX_RETRY_DELAY_SECONDS = 60


def retry_delay(response: requests.Response, attempt: int) -> float:
    retry_after_ms = response.headers.get("retry-after-ms")
    if retry_after_ms is not None:
        try:
            return min(max(float(retry_after_ms) / 1000, 0), MAX_RETRY_DELAY_SECONDS)
        except ValueError:
            pass

    retry_after = response.headers.get("retry-after")
    if retry_after is not None:
        try:
            delay = float(retry_after)
        except ValueError:
            try:
                delay = (parsedate_to_datetime(retry_after) - datetime.now(timezone.utc)).total_seconds()
            except (TypeError, ValueError, OverflowError):
                delay = None
        if delay is not None:
            return min(max(delay, 0), MAX_RETRY_DELAY_SECONDS)

    return min(2**attempt, 30)


def post_with_rate_limit_retries(url: str, *, headers: dict, json_body: dict) -> requests.Response:
    attempt = 0
    while True:
        response = requests.post(url, headers=headers, json=json_body, timeout=90)
        if response.status_code != 429:
            response.raise_for_status()
            return response
        if attempt == MAX_RATE_LIMIT_RETRIES:
            response.raise_for_status()
        time.sleep(retry_delay(response, attempt))
        attempt += 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--deployment", default="medtriage-base")
    parser.add_argument("--token", default=os.environ.get("AZURE_ACCESS_TOKEN"))
    parser.add_argument("--validation-file", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=10)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--api-version", default="2024-10-21")
    args = parser.parse_args()
    if not args.token:
        raise SystemExit("Provide --token or set AZURE_ACCESS_TOKEN.")
    rows = [json.loads(line) for line in args.validation_file.read_text(encoding="utf-8").splitlines() if line.strip()]
    results = []
    for row in rows[:args.samples]:
        expected = json.loads(row["messages"][-1]["content"])
        response = post_with_rate_limit_retries(
            f"{args.endpoint.rstrip('/')}/openai/deployments/{args.deployment}/chat/completions?api-version={args.api_version}",
            headers={"Authorization": f"Bearer {args.token}", "Content-Type": "application/json"},
            json_body={"messages": row["messages"][:-1], "temperature": 0, "response_format": {"type": "json_object"}},
        )
        content = response.json()["choices"][0]["message"]["content"]
        try:
            actual = json.loads(content)
            schema_ok = set(actual) == EXPECTED_KEYS and all(isinstance(actual[key], str) and actual[key] for key in EXPECTED_KEYS)
            urgency_match = actual.get("urgency") == expected["urgency"]
        except (ValueError, TypeError):
            schema_ok = False
            urgency_match = False
        results.append({"schema_ok": schema_ok, "urgency_match": urgency_match})
    summary = {
        "samples": len(results),
        "json_schema_rate": sum(item["schema_ok"] for item in results) / len(results),
        "urgency_match_rate": sum(item["urgency_match"] for item in results) / len(results),
    }
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
