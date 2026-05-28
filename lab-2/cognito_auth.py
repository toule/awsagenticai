# /tmp/awsagenticai/lab-2/cognito_auth.py
"""
Lab 2 - Cognito M2M (Machine-to-Machine) Token Helper.

Retrieves OAuth2 client credentials from SSM Parameter Store and
obtains an access token from Cognito for MCP server authentication.
"""

import base64

import boto3
import requests
from botocore.config import Config

RETRY_CONFIG = Config(
    retries={"max_attempts": 5, "mode": "adaptive"},
    read_timeout=30,
)

SSM_PREFIX = "/workshop/agenticai"


def get_ssm_parameter(name: str, default: str = None) -> str:
    """Retrieve a parameter from SSM Parameter Store."""
    ssm = boto3.client("ssm", config=RETRY_CONFIG)
    try:
        response = ssm.get_parameter(Name=f"{SSM_PREFIX}/{name}", WithDecryption=True)
        return response["Parameter"]["Value"]
    except ssm.exceptions.ParameterNotFound:
        if default is not None:
            return default
        raise


def get_cognito_token() -> str:
    """
    Obtain an M2M access token from Cognito using client credentials grant.

    Returns:
        str: The access token for authenticating with the MCP server.
    """
    token_endpoint = get_ssm_parameter("cognito_token_endpoint")
    client_id = get_ssm_parameter("cognito_client_id")
    client_secret = get_ssm_parameter("cognito_client_secret")

    # Encode credentials for Basic auth
    credentials = f"{client_id}:{client_secret}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {encoded_credentials}",
    }

    data = {
        "grant_type": "client_credentials",
        "scope": "api/read",
    }

    response = requests.post(token_endpoint, headers=headers, data=data, timeout=10)
    response.raise_for_status()

    token_data = response.json()
    return token_data["access_token"]


if __name__ == "__main__":
    token = get_cognito_token()
    print(f"Access token (first 20 chars): {token[:20]}...")
    print("Token obtained successfully.")
