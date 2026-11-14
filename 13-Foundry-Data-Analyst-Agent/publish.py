"""Upload the teaching CSVs and register a new version of the Foundry prompt agent."""
from pathlib import Path

from azure.ai.projects.models import AutoCodeInterpreterToolParam, CodeInterpreterTool, PromptAgentDefinition

from agent_common import AGENT_NAME, project_client

ROOT = Path(__file__).resolve().parent
FILES = [ROOT / "data" / f"{name}.csv" for name in ("orders", "order_items", "customers", "sellers")]


def main():
    instructions = (ROOT / "instructions" / "system.txt").read_text(encoding="utf-8").strip()
    if not instructions:
        raise ValueError("instructions/system.txt is empty")
    import os
    model = os.getenv("FOUNDRY_MODEL_DEPLOYMENT", "").strip()
    if not model:
        raise ValueError("Set FOUNDRY_MODEL_DEPLOYMENT to an existing model deployment name")
    with project_client() as project, project.get_openai_client() as openai:
        file_ids = []
        for path in FILES:
            with path.open("rb") as data:
                uploaded = openai.files.create(purpose="assistants", file=data)
            file_ids.append(uploaded.id)
            print(f"Uploaded {path.name}: {uploaded.id}")
        tool = CodeInterpreterTool(container=AutoCodeInterpreterToolParam(file_ids=file_ids))
        agent = project.agents.create_version(
            agent_name=AGENT_NAME,
            definition=PromptAgentDefinition(model=model, instructions=instructions, tools=[tool]),
        )
        print(f"Registered agent {agent.name} version {agent.version} using {model}")


if __name__ == "__main__":
    main()
