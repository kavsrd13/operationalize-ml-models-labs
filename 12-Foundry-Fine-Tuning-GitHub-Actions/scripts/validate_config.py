#!/usr/bin/env python3
"""Validate the Exercise 12 model choice before Azure uploads or paid training."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


APPROVED_MODEL = "gpt-4.1-mini-2025-04-14"
APPROVED_METHOD = "supervised"
APPROVED_TRAINING_TYPE = "GlobalStandard"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--github-env", type=Path)
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    exercise_dir = args.config.resolve().parents[1]
    data_dir = (exercise_dir / "data").resolve()

    def resolve_dataset(key: str, kind: str) -> Path:
        configured_path = config.get(key)
        if configured_path is not None:
            if not isinstance(configured_path, str) or not configured_path.strip():
                raise SystemExit(f"{key} must name a JSONL file inside the data folder.")
            if "\n" in configured_path or "\r" in configured_path:
                raise SystemExit(f"{key} cannot contain a newline.")
            resolved = (exercise_dir / configured_path).resolve()
        else:
            candidates = []
            for candidate in data_dir.rglob("*.jsonl"):
                name = candidate.stem.lower()
                if kind == "training" and "train" in name and "valid" not in name:
                    candidates.append(candidate.resolve())
                if kind == "validation" and ("validation" in name or "valid" in name or name.startswith("val")):
                    candidates.append(candidate.resolve())
            if len(candidates) != 1:
                names = ", ".join(str(path.name) for path in candidates) or "none"
                raise SystemExit(
                    f"Expected exactly one {kind} JSONL file in {data_dir}; found {names}. "
                    f"Rename the file to include '{kind}' or set {key} in finetune.json."
                )
            resolved = candidates[0]

        if data_dir != resolved.parent and data_dir not in resolved.parents:
            raise SystemExit(f"{key} must stay inside {data_dir}.")
        if resolved.suffix.lower() != ".jsonl":
            raise SystemExit(f"{key} must point to a .jsonl file.")
        return resolved

    resolved_files = {
        "training_file": resolve_dataset("training_file", "training"),
        "validation_file": resolve_dataset("validation_file", "validation"),
    }

    if resolved_files["training_file"] == resolved_files["validation_file"]:
        raise SystemExit("training_file and validation_file must be different files.")
    if config.get("model") != APPROVED_MODEL:
        raise SystemExit(
            f"Exercise 12 requires {APPROVED_MODEL}. "
            "The previous gpt-4o-mini fine-tuned model has no deployment quota "
            "in the configured teaching subscription."
        )
    if config.get("training_type") != APPROVED_TRAINING_TYPE:
        raise SystemExit(
            f"Exercise 12 requires training_type={APPROVED_TRAINING_TYPE}."
        )
    if config.get("method") != APPROVED_METHOD:
        raise SystemExit(f"Exercise 12 requires method={APPROVED_METHOD}.")

    hyperparameters = config.get("hyperparameters")
    if not isinstance(hyperparameters, dict):
        raise SystemExit("hyperparameters must be a JSON object.")
    expected_hyperparameters = {"n_epochs", "batch_size", "learning_rate_multiplier"}
    if set(hyperparameters) != expected_hyperparameters:
        raise SystemExit(
            f"hyperparameters must contain exactly {sorted(expected_hyperparameters)}."
        )
    n_epochs = hyperparameters["n_epochs"]
    batch_size = hyperparameters["batch_size"]
    learning_rate = hyperparameters["learning_rate_multiplier"]
    if not isinstance(n_epochs, int) or isinstance(n_epochs, bool) or not 1 <= n_epochs <= 5:
        raise SystemExit("hyperparameters.n_epochs must be an integer from 1 to 5.")
    if not isinstance(batch_size, int) or isinstance(batch_size, bool) or not 1 <= batch_size <= 32:
        raise SystemExit("hyperparameters.batch_size must be an integer from 1 to 32.")
    if (
        not isinstance(learning_rate, (int, float))
        or isinstance(learning_rate, bool)
        or not 0.1 <= learning_rate <= 2.0
    ):
        raise SystemExit("hyperparameters.learning_rate_multiplier must be between 0.1 and 2.0.")

    seed = config.get("seed")
    if not isinstance(seed, int) or isinstance(seed, bool) or not 0 <= seed <= 2_147_483_647:
        raise SystemExit("seed must be an integer from 0 to 2147483647.")
    suffix = config.get("suffix")
    if not isinstance(suffix, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", suffix):
        raise SystemExit("suffix must be 1-40 letters, numbers, hyphens, or underscores.")

    print(
        f"Configuration valid: model={APPROVED_MODEL}, method={APPROVED_METHOD}, "
        f"training_type={APPROVED_TRAINING_TYPE}, hyperparameters={hyperparameters}"
    )
    print(f"Training data: {resolved_files['training_file']}")
    print(f"Validation data: {resolved_files['validation_file']}")

    if args.github_env:
        with args.github_env.open("a", encoding="utf-8", newline="\n") as env_file:
            env_file.write(f"MEDTRIAGE_TRAINING_FILE={resolved_files['training_file']}\n")
            env_file.write(f"MEDTRIAGE_VALIDATION_FILE={resolved_files['validation_file']}\n")


if __name__ == "__main__":
    main()
