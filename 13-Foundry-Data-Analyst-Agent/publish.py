"""Upload the teaching CSVs and register a Foundry Code Interpreter agent."""
import os
from pathlib import Path

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import AutoCodeInterpreterToolParam, CodeInterpreterTool, PromptAgentDefinition

from agent_common import AGENT_NAME

ROOT = Path(__file__).resolve().parent
FILES = [ROOT / "data" / f"{name}.csv" for name in ("orders", "order_items", "customers", "sellers")]


def main():
    instructions = (ROOT / "instructions" / "system.txt").read_text(encoding="utf-8").strip()
    if not instructions:
        raise ValueError("instructions/system.txt is empty")
    model = os.getenv("FOUNDRY_MODEL_DEPLOYMENT", "").strip()
    if not model:
        raise ValueError("Set FOUNDRY_MODEL_DEPLOYMENT to an existing model deployment name")
    endpoint = os.getenv("FOUNDRY_PROJECT_ENDPOINT", "").strip()
    if not endpoint or "/api/projects/" not in endpoint:
        raise ValueError("Set FOUNDRY_PROJECT_ENDPOINT to the full Foundry project endpoint")

    # Follow the Microsoft Learn Python Code Interpreter sample.
    project = AIProjectClient(endpoint=endpoint, credential=DefaultAzureCredential())
    openai = project.get_openai_client()

    file_ids = []
    for path in FILES:
        with path.open("rb") as csv_file:
            file = openai.files.create(purpose="assistants", file=csv_file)
        file_ids.append(file.id)
        print(f"Uploaded {path.name}: {file.id}")

    agent = project.agents.create_version(
        agent_name=AGENT_NAME,
        definition=PromptAgentDefinition(
            model=model,
            instructions=instructions,
            tools=[CodeInterpreterTool(container=AutoCodeInterpreterToolParam(file_ids=file_ids))],
        ),
        description="Code Interpreter agent for Olist teaching data analysis.",
    )
    print(f"Registered agent {agent.name} version {agent.version} using {model}")


if __name__ == "__main__":
    main()
