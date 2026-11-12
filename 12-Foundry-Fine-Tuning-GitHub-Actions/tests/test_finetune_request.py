from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


EXERCISE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(EXERCISE_DIR / "scripts"))

from submit_finetune import build_job_request  # noqa: E402


class FineTuneRequestTests(unittest.TestCase):
    def test_sft_hyperparameters_use_official_sdk_shape(self) -> None:
        config = json.loads((EXERCISE_DIR / "config" / "finetune.json").read_text(encoding="utf-8"))
        request = build_job_request(config, "file-training", "file-validation")

        self.assertEqual(request["method"]["type"], "supervised")
        self.assertEqual(
            request["method"]["supervised"]["hyperparameters"],
            {"n_epochs": 2, "batch_size": 4, "learning_rate_multiplier": 0.5},
        )
        self.assertEqual(request["extra_body"], {"trainingType": "GlobalStandard"})
        self.assertEqual(request["seed"], 42)
        self.assertNotIn("trainingType", request["method"]["supervised"]["hyperparameters"])


if __name__ == "__main__":
    unittest.main()
