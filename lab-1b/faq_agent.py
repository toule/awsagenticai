# /tmp/awsagenticai/lab-1b/faq_agent.py
"""
Lab 1b - FAQ Agent using Strands Agents SDK with Knowledge Base Retrieve.

Retrieves model_id and kb_id from SSM Parameter Store.
Uses Bedrock Knowledge Base as a tool for RAG-based FAQ answering.
"""

import boto3
from botocore.config import Config
from strands import Agent
from strands.models.bedrock import BedrockModel
from strands_tools import retrieve

# --- Configuration ---
RETRY_CONFIG = Config(
    retries={"max_attempts": 5, "mode": "adaptive"},
    read_timeout=120,
)

SSM_PREFIX = "/workshop/agenticai"


def get_ssm_parameter(name: str, default: str = None) -> str:
    """Retrieve a parameter from SSM Parameter Store."""
    ssm = boto3.client("ssm")
    try:
        response = ssm.get_parameter(Name=f"{SSM_PREFIX}/{name}")
        return response["Parameter"]["Value"]
    except ssm.exceptions.ParameterNotFound:
        if default is not None:
            return default
        raise


def create_faq_agent() -> Agent:
    """Create and return the FAQ agent with KB retrieve tool."""
    model_id = get_ssm_parameter(
        "agent_model_id",
        default="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )
    kb_id = get_ssm_parameter("kb_id")

    bedrock_model = BedrockModel(
        model_id=model_id,
        boto_client_config=RETRY_CONFIG,
    )

    system_prompt = f"""You are a helpful FAQ assistant for our company.
Use the retrieve tool to search the knowledge base (knowledge_base_id: {kb_id})
for relevant information before answering questions.
Always cite the source documents when providing answers.
If you cannot find relevant information, say so clearly."""

    agent = Agent(
        model=bedrock_model,
        system_prompt=system_prompt,
        tools=[retrieve],
    )
    return agent


def main():
    """Run the FAQ agent in interactive mode."""
    print("=" * 60)
    print("FAQ Agent (Lab 1b) - Knowledge Base Retrieve")
    print("=" * 60)

    agent = create_faq_agent()

    while True:
        try:
            question = input("\nYou: ").strip()
            if question.lower() in ("quit", "exit", "q"):
                print("Goodbye!")
                break
            if not question:
                continue

            response = agent(question)
            print(f"\nAssistant: {response}")

        except KeyboardInterrupt:
            print("\nGoodbye!")
            break


if __name__ == "__main__":
    main()
