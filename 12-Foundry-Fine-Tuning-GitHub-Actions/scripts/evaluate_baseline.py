#!/usr/bin/env python3
"""Run a small, repeatable base-model baseline against the held-out validation split."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import requests

EXPECTED_KEYS = {"urgency", "department", "reason", "next_step"}


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
        response = requests.post(
            f"{args.endpoint.rstrip('/')}/openai/deployments/{args.deployment}/chat/completions?api-version={args.api_version}",
            headers={"Authorization": f"Bearer {args.token}", "Content-Type": "application/json"},
            json={"messages": row["messages"][:-1], "temperature": 0, "response_format": {"type": "json_object"}},
            timeout=90,
        )
        response.raise_for_status()
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
