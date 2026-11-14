"""Talk to the latest registered agent version in your terminal."""
from agent_common import AGENT_NAME, project_client


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
        finally:
            openai.conversations.delete(conversation_id=conversation.id)


if __name__ == "__main__":
    main()
