#!/usr/bin/env python3
"""Validate the Exercise 12 model choice before Azure uploads or paid training."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


APPROVED_MODEL = "gpt-4.1-mini-2025-04-14"
APPROVED_TRAINING_TYPE = "globalStandard"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
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
    if not isinstance(config.get("n_epochs"), int) or config["n_epochs"] < 1:
        raise SystemExit("n_epochs must be a positive integer.")
    if not isinstance(config.get("learning_rate_multiplier"), (int, float)) or config["learning_rate_multiplier"] <= 0:
        raise SystemExit("learning_rate_multiplier must be greater than zero.")
    if not isinstance(config.get("suffix"), str) or not config["suffix"].strip():
        raise SystemExit("suffix must be a non-empty string.")

    print(
        f"Configuration valid: model={APPROVED_MODEL}, "
        f"training_type={APPROVED_TRAINING_TYPE}"
    )


if __name__ == "__main__":
    main()
