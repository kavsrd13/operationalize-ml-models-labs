from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


EXERCISE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(EXERCISE_DIR / "scripts"))

import foundry_sdk  # noqa: E402


class FoundryClientRetryTests(unittest.TestCase):
    @patch.object(foundry_sdk, "AIProjectClient")
    @patch.object(foundry_sdk, "DefaultAzureCredential")
    def test_openai_client_retries_transient_throttling(self, credential_type, project_type) -> None:
        credential_resource = MagicMock()
        credential = MagicMock()
        credential_resource.__enter__.return_value = credential
        credential_type.return_value = credential_resource

        project_resource = MagicMock()
        project_client = MagicMock()
        project_resource.__enter__.return_value = project_client
        project_type.return_value = project_resource

        openai_resource = MagicMock()
        openai_client = MagicMock()
        openai_resource.__enter__.return_value = openai_client
        project_client.get_openai_client.return_value = openai_resource

        with foundry_sdk.open_project_client("https://example.services.ai.azure.com/api/projects/demo") as client:
            self.assertIs(client, openai_client)

        project_client.get_openai_client.assert_called_once_with(max_retries=5)


if __name__ == "__main__":
    unittest.main()
