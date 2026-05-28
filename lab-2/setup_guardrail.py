# /tmp/awsagenticai/lab-2/setup_guardrail.py
"""
Lab 2 - Guardrail Idempotent Setup.

Creates or updates a Bedrock Guardrail for the product search agent.
Stores the guardrail ID and version in SSM Parameter Store.
Idempotent: safe to run multiple times.
"""

import boto3
from botocore.config import Config

RETRY_CONFIG = Config(
    retries={"max_attempts": 5, "mode": "adaptive"},
    read_timeout=60,
)

SSM_PREFIX = "/workshop/agenticai"
GUARDRAIL_NAME = "product-search-guardrail"


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


def put_ssm_parameter(name: str, value: str) -> None:
    """Store a parameter in SSM Parameter Store."""
    ssm = boto3.client("ssm", config=RETRY_CONFIG)
    ssm.put_parameter(
        Name=f"{SSM_PREFIX}/{name}",
        Value=value,
        Type="String",
        Overwrite=True,
    )


def find_existing_guardrail(bedrock_client) -> dict | None:
    """Find an existing guardrail by name."""
    paginator = bedrock_client.get_paginator("list_guardrails")
    for page in paginator.paginate():
        for guardrail in page.get("guardrails", []):
            if guardrail["name"] == GUARDRAIL_NAME:
                return guardrail
    return None


def setup_guardrail() -> tuple[str, str]:
    """
    Create or update the guardrail. Returns (guardrail_id, version).

    Idempotent: if the guardrail already exists, it updates it.
    """
    bedrock = boto3.client("bedrock", config=RETRY_CONFIG)

    guardrail_config = {
        "name": GUARDRAIL_NAME,
        "description": "Guardrail for product search agent - blocks harmful content and PII",
        "topicPolicyConfig": {
            "topicsConfig": [
                {
                    "name": "Competitor_Products",
                    "definition": "Questions about or recommendations for competitor products",
                    "examples": [
                        "What do you think about competitor X?",
                        "Is competitor Y better than your product?",
                    ],
                    "type": "DENY",
                },
                {
                    "name": "Harmful_Content",
                    "definition": "Requests for harmful, illegal, or dangerous content",
                    "examples": [
                        "How to use products for illegal purposes",
                    ],
                    "type": "DENY",
                },
            ]
        },
        "contentPolicyConfig": {
            "filtersConfig": [
                {"type": "SEXUAL", "inputStrength": "HIGH", "outputStrength": "HIGH"},
                {"type": "VIOLENCE", "inputStrength": "HIGH", "outputStrength": "HIGH"},
                {"type": "HATE", "inputStrength": "HIGH", "outputStrength": "HIGH"},
                {"type": "INSULTS", "inputStrength": "HIGH", "outputStrength": "HIGH"},
                {"type": "MISCONDUCT", "inputStrength": "HIGH", "outputStrength": "HIGH"},
                {"type": "PROMPT_ATTACK", "inputStrength": "HIGH", "outputStrength": "NONE"},
            ]
        },
        "sensitiveInformationPolicyConfig": {
            "piiEntitiesConfig": [
                {"type": "EMAIL", "action": "ANONYMIZE"},
                {"type": "PHONE", "action": "ANONYMIZE"},
                {"type": "US_SOCIAL_SECURITY_NUMBER", "action": "BLOCK"},
                {"type": "CREDIT_DEBIT_CARD_NUMBER", "action": "BLOCK"},
            ]
        },
        "blockedInputMessaging": "I cannot process this request as it violates our content policy.",
        "blockedOutputsMessaging": "I cannot provide this response as it violates our content policy.",
    }

    existing = find_existing_guardrail(bedrock)

    if existing:
        guardrail_id = existing["id"]
        print(f"Updating existing guardrail: {guardrail_id}")
        response = bedrock.update_guardrail(
            guardrailIdentifier=guardrail_id,
            **guardrail_config,
        )
        version = response["version"]
    else:
        print("Creating new guardrail...")
        response = bedrock.create_guardrail(**guardrail_config)
        guardrail_id = response["guardrailId"]
        version = response["version"]

    # Store in SSM for other components to use
    put_ssm_parameter("guardrail_id", guardrail_id)
    put_ssm_parameter("guardrail_version", version)

    print(f"Guardrail ID: {guardrail_id}")
    print(f"Guardrail Version: {version}")
    return guardrail_id, version


if __name__ == "__main__":
    gid, ver = setup_guardrail()
    print(f"\nSetup complete. Guardrail {gid} (v{ver}) stored in SSM.")
