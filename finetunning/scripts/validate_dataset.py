#!/usr/bin/env python3
"""Validate the MedTriage JSONL data before any paid fine-tuning job is submitted."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

REQUIRED_KEYS = {"urgency", "department", "reason", "next_step"}
ALLOWED_URGENCY = {"Emergency", "Urgent", "Routine", "Not Applicable"}


def read_records(path: Path) -> tuple[list[dict], list[str]]:
    records: list[dict] = []
    errors: list[str] = []
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw_line.strip():
            errors.append(f"{path.name}:{line_number}: blank lines are not allowed")
            continue
        try:
            record = json.loads(raw_line)
            messages = record["messages"]
            if [message.get("role") for message in messages] != ["system", "user", "assistant"]:
                raise ValueError("messages must be exactly system, user, assistant")
            assistant = json.loads(messages[-1]["content"])
            if set(assistant) != REQUIRED_KEYS:
                raise ValueError(f"assistant JSON keys must be exactly {sorted(REQUIRED_KEYS)}")
            if assistant["urgency"] not in ALLOWED_URGENCY:
                raise ValueError(f"invalid urgency {assistant['urgency']!r}")
            if any(not isinstance(assistant[key], str) or not assistant[key].strip() for key in REQUIRED_KEYS):
                raise ValueError("every assistant JSON value must be a non-empty string")
            records.append(record)
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            errors.append(f"{path.name}:{line_number}: {error}")
    return records, errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("training", type=Path)
    parser.add_argument("validation", type=Path)
    args = parser.parse_args()
    training, training_errors = read_records(args.training)
    validation, validation_errors = read_records(args.validation)
    errors = training_errors + validation_errors
    train_questions = {row["messages"][1]["content"].strip() for row in training}
    validation_questions = {row["messages"][1]["content"].strip() for row in validation}
    overlap = train_questions & validation_questions
    if overlap:
        errors.append(f"training/validation overlap: {len(overlap)} identical user messages")
    system_prompts = {row["messages"][0]["content"] for row in training + validation}
    print(f"Training examples: {len(training)}")
    print(f"Validation examples: {len(validation)}")
    print(f"System prompts: {len(system_prompts)}")
    print(f"Train/validation overlap: {len(overlap)}")
    if errors:
        print("Dataset validation failed:")
        print("\n".join(errors[:20]))
        raise SystemExit(1)
    print("Dataset validation passed.")


if __name__ == "__main__":
    main()
