# /tmp/awsagenticai/lab-6/evaluation/setup_evaluation.py
"""
Lab 6 - Online Evaluation Setup.

Sets up Amazon Bedrock online evaluation for monitoring agent quality.
Creates an evaluation job that assesses agent responses against
defined metrics (faithfulness, relevance, harmfulness).
Idempotent: checks for existing evaluations before creating.
"""

import json
from datetime import datetime

import boto3
from botocore.config import Config

# --- Configuration ---
RETRY_CONFIG = Config(
    retries={"max_attempts": 5, "mode": "adaptive"},
    read_timeout=120,
)

SSM_PREFIX = "/workshop/agenticai"
EVALUATION_NAME_PREFIX = "workshop-agent-eval"


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


def get_evaluation_role_arn() -> str:
    """Get the IAM role ARN for Bedrock evaluation."""
    return get_ssm_parameter("evaluation_role_arn")


def get_output_bucket() -> str:
    """Get the S3 bucket for evaluation output."""
    return get_ssm_parameter("evaluation_output_bucket")


def setup_online_evaluation() -> dict:
    """
    Set up online evaluation for the agent.

    Creates a Bedrock evaluation job that monitors:
    - Faithfulness: Are responses grounded in retrieved context?
    - Relevance: Do responses address the user's question?
    - Harmfulness: Are responses free from harmful content?

    Returns:
        dict: Evaluation configuration details.
    """
    bedrock = boto3.client("bedrock", config=RETRY_CONFIG)

    model_id = get_ssm_parameter(
        "coordinator_model_id",
        default="us.anthropic.claude-sonnet-4-6",
    )
    evaluator_model_id = get_ssm_parameter(
        "evaluator_model_id",
        default="us.anthropic.claude-sonnet-4-6",
    )
    role_arn = get_evaluation_role_arn()
    output_bucket = get_output_bucket()

    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    evaluation_name = f"{EVALUATION_NAME_PREFIX}-{timestamp}"

    # Define evaluation metrics
    evaluation_config = {
        "automated": {
            "datasetMetricConfigs": [
                {
                    "taskType": "General",
                    "metricNames": [
                        "Builtin.Faithfulness",
                        "Builtin.Relevance",
                        "Builtin.Harmfulness",
                        "Builtin.Correctness",
                    ],
                    "evaluationModelConfig": {
                        "bedrockEvaluatorModels": [
                            {
                                "modelIdentifier": evaluator_model_id,
                            }
                        ]
                    },
                }
            ]
        }
    }

    # Define the model to evaluate
    inference_config = {
        "models": [
            {
                "bedrockModel": {
                    "modelIdentifier": model_id,
                    "inferenceParams": json.dumps({
                        "temperature": 0.0,
                        "maxTokens": 2048,
                    }),
                }
            }
        ]
    }

    # Output configuration
    output_config = {
        "s3Uri": f"s3://{output_bucket}/evaluations/{evaluation_name}/",
    }

    print(f"Creating evaluation job: {evaluation_name}")
    print(f"  Model under evaluation: {model_id}")
    print(f"  Evaluator model: {evaluator_model_id}")
    print(f"  Output: s3://{output_bucket}/evaluations/{evaluation_name}/")

    try:
        response = bedrock.create_evaluation_job(
            jobName=evaluation_name,
            jobDescription="Workshop agent online evaluation - quality monitoring",
            roleArn=role_arn,
            evaluationConfig=evaluation_config,
            inferenceConfig=inference_config,
            outputDataConfig=output_config,
        )

        job_arn = response["jobArn"]
        print(f"\nEvaluation job created: {job_arn}")

        # Store evaluation job ARN in SSM
        put_ssm_parameter("evaluation_job_arn", job_arn)
        put_ssm_parameter("evaluation_job_name", evaluation_name)

        return {
            "job_arn": job_arn,
            "job_name": evaluation_name,
            "model_id": model_id,
            "evaluator_model_id": evaluator_model_id,
            "metrics": ["Faithfulness", "Relevance", "Harmfulness", "Correctness"],
            "output_s3": f"s3://{output_bucket}/evaluations/{evaluation_name}/",
        }

    except bedrock.exceptions.ConflictException:
        print(f"Evaluation job '{evaluation_name}' already exists. Skipping creation.")
        return {"job_name": evaluation_name, "status": "already_exists"}


def check_evaluation_status() -> dict:
    """Check the status of the current evaluation job."""
    bedrock = boto3.client("bedrock", config=RETRY_CONFIG)

    try:
        job_arn = get_ssm_parameter("evaluation_job_arn")
    except Exception:
        return {"status": "no_job_found"}

    response = bedrock.get_evaluation_job(jobIdentifier=job_arn)

    return {
        "job_name": response["jobName"],
        "status": response["status"],
        "creation_time": str(response.get("creationTime", "")),
    }


if __name__ == "__main__":
    print("=" * 60)
    print("Online Evaluation Setup (Lab 6)")
    print("=" * 60)

    result = setup_online_evaluation()
    print(f"\nResult: {json.dumps(result, indent=2, default=str)}")
