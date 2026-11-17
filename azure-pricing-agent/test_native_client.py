import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import foundry_native_pricing as native
import verify_native_report as verifier
from verify_native_report import reconcile


ENVIRONMENT = {
    "AZURE_AI_PROJECT_ENDPOINT": "https://example-pricing.services.ai.azure.com/api/projects/pricing",
    "AZURE_AI_PROJECT_ARM_ID": (
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example"
        "/providers/Microsoft.CognitiveServices/accounts/example-pricing/projects/pricing"
    ),
}


class NativeClientTests(unittest.TestCase):
    def test_missing_target_fails_before_credentials_or_cloud_writes(self):
        with patch.dict("os.environ", {}, clear=True), patch.object(native, "AzureCliCredential") as credential:
            with self.assertRaisesRegex(ValueError, "Set AZURE_AI_PROJECT_ENDPOINT"):
                native.deploy()
            credential.assert_not_called()

    def test_target_requires_a_matching_project_arm_id(self):
        env = dict(ENVIRONMENT)
        env["AZURE_AI_PROJECT_ARM_ID"] += "-different"
        with patch.dict("os.environ", env, clear=True):
            with self.assertRaisesRegex(ValueError, "different projects"):
                native.Settings.from_environment()
        env["AZURE_AI_PROJECT_ARM_ID"] = "/subscriptions/not-a-project"
        with patch.dict("os.environ", env, clear=True):
            with self.assertRaisesRegex(ValueError, "Cognitive Services"):
                native.Settings.from_environment()

    def test_rejects_foreign_or_credential_bearing_endpoints(self):
        for endpoint in (
            "http://example-pricing.services.ai.azure.com/api/projects/pricing",
            "https://prices.azure.com/api/projects/pricing",
            "https://example-pricing.services.ai.azure.com.evil.example/api/projects/pricing",
            "https://user:password@example-pricing.services.ai.azure.com/api/projects/pricing",
            ENVIRONMENT["AZURE_AI_PROJECT_ENDPOINT"] + "?api-key=example",
            ENVIRONMENT["AZURE_AI_PROJECT_ENDPOINT"] + "#fragment",
            "https://example-pricing.services.ai.azure.com/api/projects/pricing:443",
        ):
            with self.subTest(endpoint=endpoint), self.assertRaises(ValueError):
                native.validate_endpoint(endpoint)

    def test_deploy_uses_configured_target_and_native_tools(self):
        project = MagicMock()
        project.__enter__.return_value = project
        client = MagicMock()
        project.get_openai_client.return_value.__enter__.return_value = client
        client.files.create.return_value.id = "file-example"
        toolbox = SimpleNamespace(name="test-toolbox", version="1")
        project.toolboxes.create_version.side_effect = lambda **args: SimpleNamespace(
            name=toolbox.name, version=toolbox.version, tools=args["tools"],
        )
        project.toolboxes.get_version.side_effect = lambda **args: SimpleNamespace(
            tools=project.toolboxes.create_version.call_args.kwargs["tools"],
            as_dict=lambda: {"name": toolbox.name, "version": toolbox.version},
        )
        created = []

        def create_agent(**args):
            agent = SimpleNamespace(
                name=args["agent_name"], version="1", definition=args["definition"],
                as_dict=lambda: {"definition": args["definition"].as_dict()},
            )
            created.append(agent)
            return agent

        project.agents.create_version.side_effect = create_agent
        project.agents.get_version.side_effect = lambda **args: created[-1]
        env = {
            **ENVIRONMENT, "AZURE_AI_MODEL_DEPLOYMENT": "test-gpt5",
            "AZURE_AI_AGENT_NAME": "test-agent", "AZURE_AI_TOOLBOX_NAME": toolbox.name,
        }
        with tempfile.TemporaryDirectory() as folder:
            config_path = Path(folder) / "state" / "deployment.json"
            with (
                patch.dict("os.environ", env, clear=True),
                patch.object(native, "AzureCliCredential"),
                patch.object(native, "AIProjectClient", return_value=project) as factory,
                patch.object(native, "ensure_connection", side_effect=lambda credential, connection_id, *args: connection_id),
                redirect_stdout(io.StringIO()),
            ):
                native.deploy(config_path)
            factory.assert_called_once()
            self.assertEqual(factory.call_args.kwargs["endpoint"], env["AZURE_AI_PROJECT_ENDPOINT"])
            config = json.loads(config_path.read_text(encoding="utf-8"))
            self.assertEqual(config["agent_name"], "test-agent")
            self.assertEqual(config["model_deployment"], "test-gpt5")
            self.assertEqual(config["toolbox_version"], "1")
            definition = created[-1].definition.as_dict()
            self.assertEqual(definition["model"], "test-gpt5")
            mcp, interpreter = definition["tools"]
            self.assertEqual(mcp["type"], "mcp")
            self.assertEqual(mcp["server_url"], config["toolbox_url"])
            self.assertEqual(mcp["project_connection_id"], config["toolbox_connection_id"])
            self.assertEqual(interpreter["type"], "code_interpreter")
            self.assertEqual(interpreter["container"]["network_policy"]["type"], "disabled")
            self.assertEqual(interpreter["container"]["file_ids"], ["file-example"])
            spec = json.loads((config_path.parent / "azure_retail_prices.openapi.json").read_text())
            self.assertEqual(spec, json.loads((native.ROOT / "azure_retail_prices.openapi.json").read_text()))

    def test_mismatched_existing_connection_is_not_overwritten(self):
        credential = MagicMock()
        credential.get_token.return_value.token = "test-token"
        body = json.dumps({
            "id": "example", "properties": {"category": "RemoteTool", "target": "https://other.example"},
        }).encode()
        with patch.object(native, "urlopen", return_value=io.BytesIO(body)) as request:
            with self.assertRaisesRegex(RuntimeError, "refusing to overwrite"):
                native.ensure_connection(credential, ENVIRONMENT["AZURE_AI_PROJECT_ARM_ID"] + "/connections/test")
            self.assertEqual(request.call_count, 1)
            self.assertEqual(request.call_args.args[0].get_method(), "GET")

    def test_incomplete_invocation_preserves_response_without_retrying(self):
        with tempfile.TemporaryDirectory() as folder:
            config_path = Path(folder) / "deployment.json"
            config_path.write_text(json.dumps({
                "endpoint": ENVIRONMENT["AZURE_AI_PROJECT_ENDPOINT"],
                "agent_name": "example-agent", "agent_version": "8",
            }))
            output = Path(folder) / "results" / "response.json"
            project = MagicMock()
            project.__enter__.return_value = project
            client = MagicMock()
            project.get_openai_client.return_value.__enter__.return_value = client
            client.with_options.return_value = client
            response = SimpleNamespace(
                status="incomplete", output_text="",
                model_dump_json=lambda **kwargs: '{"status":"incomplete"}',
            )
            client.responses.create.return_value = response
            with patch.object(native, "AzureCliCredential"), patch.object(native, "AIProjectClient", return_value=project):
                with self.assertRaisesRegex(RuntimeError, "Native response incomplete"):
                    native.invoke("test", output, config_path=config_path)
            self.assertEqual(json.loads(output.read_text())["status"], "incomplete")
            client.with_options.assert_called_once_with(max_retries=0, timeout=180)
            reference = client.responses.create.call_args.kwargs["extra_body"]["agent_reference"]
            self.assertEqual(reference["version"], "8")

    def test_verifier_rejects_incomplete_or_tool_free_responses(self):
        with self.assertRaisesRegex(AssertionError, "not completed"):
            reconcile({"status": "incomplete", "output": []}, {})
        with self.assertRaisesRegex(AssertionError, "No completed native API"):
            reconcile({"status": "completed", "output": []}, {})

    def test_verifier_cli_creates_its_output_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "fixture.json"
            source.write_text("{}")
            output = Path(folder) / "results" / "reconciliation.json"
            with (
                patch("sys.argv", ["verify_native_report.py", str(source), str(source), "--output", str(output)]),
                patch.object(verifier, "reconcile", return_value={"verified": True}),
                redirect_stdout(io.StringIO()),
            ):
                verifier.main()
            self.assertEqual(json.loads(output.read_text()), {"verified": True})


if __name__ == "__main__":
    unittest.main()
