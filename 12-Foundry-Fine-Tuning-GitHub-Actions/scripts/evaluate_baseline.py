#!/usr/bin/env python3
"""Measure a repeatable base-model baseline through the Microsoft Foundry SDK."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from foundry_sdk import open_project_client


EXPECTED_KEYS = {"urgency", "department", "reason", "next_step"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-endpoint", required=True)
    parser.add_argument("--deployment", default="medtriage-base")
    parser.add_argument("--validation-file", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=10)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = [
        json.loads(line)
        for line in args.validation_file.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    results = []
    selected_rows = rows[: args.samples]
    with open_project_client(args.project_endpoint) as client:
        for index, row in enumerate(selected_rows, start=1):
            print(f"Evaluating held-out example {index}/{len(selected_rows)}", flush=True)
            expected = json.loads(row["messages"][-1]["content"])
            response = client.chat.completions.create(
                model=args.deployment,
                messages=row["messages"][:-1],
                temperature=0,
                max_completion_tokens=180,
                response_format={"type": "json_object"},
            )
            content = response.choices[0].message.content or ""
            try:
                actual = json.loads(content)
                schema_ok = set(actual) == EXPECTED_KEYS and all(
                    isinstance(actual[key], str) and actual[key] for key in EXPECTED_KEYS
                )
                urgency_match = actual.get("urgency") == expected["urgency"]
            except (ValueError, TypeError):
                schema_ok = False
                urgency_match = False
            results.append({"schema_ok": schema_ok, "urgency_match": urgency_match})

    if not results:
        raise SystemExit("The validation dataset contains no examples.")
    summary = {
        "deployment": args.deployment,
        "samples": len(results),
        "json_schema_rate": sum(item["schema_ok"] for item in results) / len(results),
        "urgency_match_rate": sum(item["urgency_match"] for item in results) / len(results),
    }
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
