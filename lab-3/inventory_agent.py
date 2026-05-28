# /tmp/awsagenticai/lab-3/inventory_agent.py
"""
Lab 3 - Inventory Agent with use_aws and DynamoDB.

Uses Strands Agents SDK with the use_aws meta-tool to interact with
DynamoDB for inventory management operations (check stock, update quantities).
"""

import boto3
from botocore.config import Config
from strands import Agent
from strands.models.bedrock import BedrockModel
from strands_tools import use_aws

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


def create_inventory_agent() -> Agent:
    """Create the inventory management agent with DynamoDB access via use_aws."""
    model_id = get_ssm_parameter(
        "agent_model_id",
        default="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )
    table_name = get_ssm_parameter("inventory_table_name")

    bedrock_model = BedrockModel(
        model_id=model_id,
        boto_client_config=RETRY_CONFIG,
    )

    system_prompt = f"""You are an inventory management agent. You manage product inventory
stored in a DynamoDB table named '{table_name}'.

The table schema:
- Partition key: product_id (String)
- Attributes: product_name, quantity, warehouse_location, last_updated, reorder_threshold

You can perform these operations using the use_aws tool with the dynamodb service:
1. Check stock levels: use get_item or query
2. Update inventory: use update_item to adjust quantities
3. List low-stock items: use scan with filter for quantity < reorder_threshold
4. Add new products: use put_item

Always confirm destructive operations before executing them.
When updating quantities, include a timestamp in last_updated.
Use ISO 8601 format for timestamps.
"""

    agent = Agent(
        model=bedrock_model,
        system_prompt=system_prompt,
        tools=[use_aws],
    )
    return agent


def main():
    """Run the inventory agent in interactive mode."""
    print("=" * 60)
    print("Inventory Agent (Lab 3) - DynamoDB via use_aws")
    print("=" * 60)

    agent = create_inventory_agent()

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
