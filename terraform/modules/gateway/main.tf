# ───── IAM — Lambda role ─────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_reviews" {
  name               = "${var.project_name}-retrieve-product-reviews-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_reviews.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_ddb" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
    resources = [var.reviews_table_arn]
  }
}

resource "aws_iam_role_policy" "lambda_ddb" {
  role   = aws_iam_role.lambda_reviews.id
  policy = data.aws_iam_policy_document.lambda_ddb.json
}

# ───── Lambda function ────────────────────────────────────────────────
data "archive_file" "retrieve_product_reviews" {
  type        = "zip"
  output_path = "${var.build_dir}/retrieve_product_reviews.zip"
  source {
    filename = "index.py"
    content  = <<-PY
      import json, os
      import boto3
      from botocore.exceptions import ClientError

      ddb = boto3.resource("dynamodb")

      def lambda_handler(event, context):
          product_id = event.get("product_id")
          if not product_id:
              return {"statusCode": 400, "body": json.dumps({"error": "product_id required"})}
          return {"statusCode": 200, "body": json.dumps(_get(product_id))}

      def _get(pid):
          try:
              table = ddb.Table(os.environ["REVIEWS_TABLE"])
              resp = table.query(
                  KeyConditionExpression="product_id = :pid",
                  ExpressionAttributeValues={":pid": pid},
              )
              items = resp.get("Items", [])
              return items if items else {"error": "No reviews found for this product"}
          except ClientError as e:
              return {"error": f"Database error: {e}"}
    PY
  }
}

resource "aws_lambda_function" "retrieve_product_reviews" {
  function_name = "${var.project_name}-retrieve-product-reviews"
  role          = aws_iam_role.lambda_reviews.arn
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.retrieve_product_reviews.output_path
  source_code_hash = data.archive_file.retrieve_product_reviews.output_base64sha256

  environment {
    variables = { REVIEWS_TABLE = var.reviews_table_name }
  }
}

resource "aws_lambda_permission" "agentcore_invoke" {
  statement_id  = "AllowAgentCoreGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieve_product_reviews.function_name
  principal     = "bedrock-agentcore.amazonaws.com"
}

# ───── IAM — AgentCore Gateway role ──────────────────────────────────
data "aws_iam_policy_document" "agentcore_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agentcore_gateway" {
  name               = "${var.project_name}-agentcore-gateway-role"
  assume_role_policy = data.aws_iam_policy_document.agentcore_assume.json
}

data "aws_iam_policy_document" "agentcore_gateway" {
  statement {
    sid       = "InvokeLambdaTargets"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.retrieve_product_reviews.arn]
  }
  statement {
    sid     = "Logs"
    effect  = "Allow"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "agentcore_gateway" {
  role   = aws_iam_role.agentcore_gateway.id
  policy = data.aws_iam_policy_document.agentcore_gateway.json
}

# ───── Cognito M2M ────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_resource_server" "agentcore" {
  identifier   = "agentcore-gateway"
  name         = "AgentCore Gateway Resource Server"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke AgentCore Gateway tools"
  }
}

resource "aws_cognito_user_pool_client" "m2m" {
  name         = "${var.project_name}-m2m-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["${aws_cognito_resource_server.agentcore.identifier}/invoke"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
}

# ───── Secrets Manager ────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "cognito_client" {
  name                    = "${var.project_name}/cognito/m2m-client"
  description             = "AgentCore Gateway 호출용 Cognito M2M client credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "cognito_client" {
  secret_id = aws_secretsmanager_secret.cognito_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.m2m.id
    client_secret = aws_cognito_user_pool_client.m2m.client_secret
    token_url     = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
    scope         = "${aws_cognito_resource_server.agentcore.identifier}/invoke"
  })
}
