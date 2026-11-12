from openai import OpenAI


endpoint = "https://<your-resource-name>.services.ai.azure.com/openai/v1/"
deployment_name = "<your-deployment-name>"
api_key = "<your-api-key>"

system_instruction = (
    "You are MedTriage, a hospital symptom triage assistant. Reply ONLY with "
    "a single JSON object with the keys urgency (Emergency | Urgent | Routine "
    "| Not Applicable), department, reason, next_step. Never give a diagnosis "
    "or medication dose. Training demo only - not for clinical use."
)

client = OpenAI(
    base_url=endpoint,
    api_key=api_key,
)

response = client.responses.create(
    model=deployment_name,
    instructions=system_instruction,
    input=(
        "My mother suddenly developed weakness on the right side of her face "
        "and arm, and her speech is unclear. What should I do?"
    ),
)

print(f"answer: {response.output_text}")
