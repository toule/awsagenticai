# /tmp/awsagenticai/lab-2/product_search_agent.py
"""
Lab 2 - Product Search Agent with MCP + Knowledge Base.

Uses Strands Agents SDK with an MCP transport for product catalog search,
combined with Bedrock Knowledge Base for enriched product information.
Authenticates to the MCP server via Cognito M2M tokens.
"""

import boto3
from botocore.config import Config
from strands import Agent
from strands.models.bedrock import BedrockModel
from strands.tools.mcp import MCPClient
from mcp.client.streamable_http import StreamableHttpTransport
from strands_tools import retrieve

from cognito_auth import get_cognito_token

# --- Configuration ---
RETRY_CONFIG = Config(
    retries={"max_attempts": 5, "mode": "adaptive"},
    read_timeout=120,
)

SSM_PREFIX = "/workshop/agenticai"


def get_ssm_parameter(name: str, default: str = None) -> str:
    """Retrieve a parameter from SSM Parameter Store."""
    ssm = boto3.client("ssm", config=RETRY_CONFIG)
    try:
        response = ssm.get_parameter(Name=f"{SSM_PREFIX}/{name}")
        return response["Parameter"]["Value"]
    except ssm.exceptions.ParameterNotFound:
        if default is not None:
            return default
        raise


def create_product_search_agent() -> Agent:
    """Create the product search agent with MCP and KB tools."""
    model_id = get_ssm_parameter(
        "agent_model_id",
        default="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )
    kb_id = get_ssm_parameter("kb_id")
    mcp_endpoint = get_ssm_parameter("mcp_endpoint")
    guardrail_id = get_ssm_parameter("guardrail_id", default=None)
    guardrail_version = get_ssm_parameter("guardrail_version", default="DRAFT")

    # Get Cognito token for MCP authentication
    access_token = get_cognito_token()

    # Configure MCP transport with auth
    mcp_transport = StreamableHttpTransport(
        url=mcp_endpoint,
        headers={"Authorization": f"Bearer {access_token}"},
    )
    mcp_client = MCPClient(transport=mcp_transport)

    # Configure Bedrock model with optional guardrails
    model_kwargs = {
        "model_id": model_id,
        "boto_client_config": RETRY_CONFIG,
    }
    if guardrail_id:
        model_kwargs["guardrail_config"] = {
            "guardrailIdentifier": guardrail_id,
            "guardrailVersion": guardrail_version,
        }

    bedrock_model = BedrockModel(**model_kwargs)

    system_prompt = f"""You are a product search assistant for an e-commerce platform.
You have access to:
1. MCP tools for searching the product catalog (search, get details, check availability)
2. A knowledge base (knowledge_base_id: {kb_id}) for product documentation and policies

When a user asks about products:
- Use MCP tools to search the catalog and get real-time data
- Use the retrieve tool for policy questions or detailed product documentation
- Provide clear, helpful responses with product details and pricing
"""

    # Combine MCP tools with KB retrieve
    with mcp_client:
        mcp_tools = mcp_client.list_tools_sync()

    agent = Agent(
        model=bedrock_model,
        system_prompt=system_prompt,
        tools=[*mcp_tools, retrieve],
    )
    return agent


def main():
    """Run the product search agent."""
    print("=" * 60)
    print("Product Search Agent (Lab 2) - MCP + Knowledge Base")
    print("=" * 60)

    agent = create_product_search_agent()

    while True:
        try:
            query = input("\nYou: ").strip()
            if query.lower() in ("quit", "exit", "q"):
                print("Goodbye!")
                break
            if not query:
                continue

            response = agent(query)
            print(f"\nAssistant: {response}")

        except KeyboardInterrupt:
            print("\nGoodbye!")
            break


if __name__ == "__main__":
    main()
