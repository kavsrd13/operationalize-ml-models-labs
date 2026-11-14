"""Talk to the latest registered agent version in your terminal."""
from pathlib import Path

from agent_common import AGENT_NAME, project_client


def download_generated_file(openai, response):
    """Download a Code Interpreter file cited in the last response message."""
    last_message = response.output[-1]
    if (
        last_message.type != "message"
        or not last_message.content
        or last_message.content[-1].type != "output_text"
        or not last_message.content[-1].annotations
    ):
        return
    file_citation = last_message.content[-1].annotations[-1]
    if file_citation.type != "container_file_citation":
        return

    file_content = openai.containers.files.content.retrieve(
        file_id=file_citation.file_id,
        container_id=file_citation.container_id,
    )
    output_dir = Path(__file__).resolve().parent / "outputs"
    output_dir.mkdir(exist_ok=True)
    file_path = output_dir / Path(file_citation.filename).name
    with file_path.open("wb") as stream:
        stream.write(file_content.read())
    print(f"Downloaded generated file: {file_path}\n")


def main():
    with project_client() as project, project.get_openai_client() as openai:
        conversation = openai.conversations.create()
        print(f"Agent: {AGENT_NAME}. Type 'exit' to quit.")
        try:
            while True:
                prompt = input("You: ").strip()
                if prompt.lower() in {"exit", "quit"}:
                    break
                if not prompt:
                    continue
                response = openai.responses.create(
                    conversation=conversation.id,
                    input=prompt,
                    extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
                )
                print(f"Agent: {response.output_text}\n")
                if any(item.type == "code_interpreter_call" for item in response.output):
                    print("[Code Interpreter ran for this answer]\n")
                download_generated_file(openai, response)
        finally:
            openai.conversations.delete(conversation_id=conversation.id)


if __name__ == "__main__":
    main()
