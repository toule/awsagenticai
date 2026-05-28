# /tmp/awsagenticai/lab-4/orchestrator.py
"""
Lab 4 - Orchestrator Agent with 3 Sub-Agents as Tools.

Coordinator agent that delegates tasks to specialized sub-agents:
1. FAQ Agent - answers product/policy questions via Knowledge Base
2. Product Search Agent - searches catalog via MCP
3. Inventory Agent - manages stock via DynamoDB

Each sub-agent is wrapped as a tool callable by the orchestrator.
"""

import boto3
from botocore.config import Config
from strands import Agent, tool
from strands.models.bedrock import BedrockModel
from strands_tools import retrieve, use_aws

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


# --- Sub-Agent Definitions ---

def _create_sub_agent_model() -> BedrockModel:
    """Create a BedrockModel for sub-agents (uses agent_model_id)."""
    model_id = get_ssm_parameter(
        "agent_model_id",
        default="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )
    return BedrockModel(model_id=model_id, boto_client_config=RETRY_CONFIG)


def _get_faq_agent() -> Agent:
    """Create the FAQ sub-agent."""
    kb_id = get_ssm_parameter("kb_id")
    return Agent(
        model=_create_sub_agent_model(),
        system_prompt=f"""You are a FAQ assistant. Use the retrieve tool to search
the knowledge base (knowledge_base_id: {kb_id}) and answer questions about
company policies, product documentation, and general FAQs.
Cite sources when possible.""",
        tools=[retrieve],
    )


def _get_inventory_agent() -> Agent:
    """Create the inventory sub-agent."""
    table_name = get_ssm_parameter("inventory_table_name")
    return Agent(
        model=_create_sub_agent_model(),
        system_prompt=f"""You are an inventory management agent.
Use the use_aws tool with DynamoDB service to query the '{table_name}' table.
Table schema: product_id (PK), product_name, quantity, warehouse_location,
last_updated, reorder_threshold.
Return concise inventory status reports.""",
        tools=[use_aws],
    )


def _get_product_search_agent() -> Agent:
    """Create the product search sub-agent (simplified without MCP for orchestrator)."""
    kb_id = get_ssm_parameter("kb_id")
    return Agent(
        model=_create_sub_agent_model(),
        system_prompt=f"""You are a product search assistant.
Use the retrieve tool to search the knowledge base (knowledge_base_id: {kb_id})
for product information, specifications, pricing, and availability.
Provide detailed product information in your responses.""",
        tools=[retrieve],
    )


# --- Tool Wrappers for Sub-Agents ---

@tool
def faq_tool(question: str) -> str:
    """Answer FAQ and policy questions using the knowledge base.

    Args:
        question: The FAQ or policy question to answer.

    Returns:
        The answer from the FAQ knowledge base.
    """
    agent = _get_faq_agent()
    result = agent(question)
    return str(result)


@tool
def product_search_tool(query: str) -> str:
    """Search for products in the catalog and return product information.

    Args:
        query: The product search query (name, category, or description).

    Returns:
        Product search results with details.
    """
    agent = _get_product_search_agent()
    result = agent(query)
    return str(result)


@tool
def inventory_tool(request: str) -> str:
    """Check or manage inventory levels in the warehouse system.

    Args:
        request: The inventory request (check stock, list low items, etc).

    Returns:
        Inventory status or operation result.
    """
    agent = _get_inventory_agent()
    result = agent(request)
    return str(result)


# --- Orchestrator ---

def create_orchestrator() -> Agent:
    """Create the orchestrator agent that coordinates sub-agents."""
    coordinator_model_id = get_ssm_parameter(
        "coordinator_model_id",
        default="us.anthropic.claude-sonnet-4-6",
    )

    bedrock_model = BedrockModel(
        model_id=coordinator_model_id,
        boto_client_config=RETRY_CONFIG,
    )

    system_prompt = """You are a coordinator agent for an e-commerce platform.
You delegate tasks to specialized sub-agents:

1. faq_tool - For policy questions, documentation, and general FAQs
2. product_search_tool - For finding products, specs, pricing, availability
3. inventory_tool - For checking stock levels, warehouse info, reorder status

Analyze each user request and route it to the appropriate sub-agent.
For complex requests, you may call multiple tools and synthesize the results.
Always provide a clear, unified response to the user."""

    agent = Agent(
        model=bedrock_model,
        system_prompt=system_prompt,
        tools=[faq_tool, product_search_tool, inventory_tool],
    )
    return agent


def main():
    """Run the orchestrator in interactive mode."""
    print("=" * 60)
    print("Orchestrator Agent (Lab 4) - Multi-Agent Coordination")
    print("=" * 60)
    print("Sub-agents: FAQ | Product Search | Inventory")
    print("=" * 60)

    orchestrator = create_orchestrator()

    while True:
        try:
            query = input("\nYou: ").strip()
            if query.lower() in ("quit", "exit", "q"):
                print("Goodbye!")
                break
            if not query:
                continue

            response = orchestrator(query)
            print(f"\nAssistant: {response}")

        except KeyboardInterrupt:
            print("\nGoodbye!")
            break


if __name__ == "__main__":
    main()
