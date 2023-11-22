terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
}

#################### DynamoDB ########################

resource "aws_dynamodb_table" "product-inventory" {
  name           = "product-inventory"
  hash_key       = "productId"
  table_class    = "STANDARD"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "productId"
    type = "S"
  }
}

################## Lambda function ####################

resource "aws_iam_role" "serverless-api-role" {
  name = "serverless-api-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:AssumeRole"
        ],
        "Principal" : {
          "Service" : [
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchFullAccess", "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"]
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "lambda_function_payload.zip"
  source {
    content  = file("./resources/lambda_function.py")
    filename = "lambda_function.py"
  }
  source {
    content  = file("./resources/custom_encoder.py")
    filename = "custom_encoder.py"
  }
}

resource "aws_lambda_function" "serverless-api" {
  function_name = "serverless-api"
  role          = aws_iam_role.serverless-api-role.arn

  architectures    = ["x86_64"]
  runtime          = "python3.9"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  filename         = "lambda_function_payload.zip"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless-api.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.serverless-api.execution_arn}/*"
}

###################### API Gateway #####################

resource "aws_api_gateway_rest_api" "serverless-api" {
  name = "serverless-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
###################### /health ######################
resource "aws_api_gateway_resource" "health-resource" {
  parent_id   = aws_api_gateway_rest_api.serverless-api.root_resource_id
  path_part   = "health"
  rest_api_id = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_method" "health-get-method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.health-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "health-get-integration" {
  http_method             = aws_api_gateway_method.health-get-method.http_method
  resource_id             = aws_api_gateway_resource.health-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}

###################### /product ######################
resource "aws_api_gateway_resource" "product-resource" {
  parent_id   = aws_api_gateway_rest_api.serverless-api.root_resource_id
  path_part   = "product"
  rest_api_id = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_method" "product-get-method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.product-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "product-get-integration" {
  http_method             = aws_api_gateway_method.product-get-method.http_method
  resource_id             = aws_api_gateway_resource.product-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}

resource "aws_api_gateway_method" "product-post-method" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.product-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "product-post-integration" {
  http_method             = aws_api_gateway_method.product-post-method.http_method
  resource_id             = aws_api_gateway_resource.product-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}

resource "aws_api_gateway_method" "product-patch-method" {
  authorization = "NONE"
  http_method   = "PATCH"
  resource_id   = aws_api_gateway_resource.product-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "product-patch-integration" {
  http_method             = aws_api_gateway_method.product-patch-method.http_method
  resource_id             = aws_api_gateway_resource.product-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}

resource "aws_api_gateway_method" "product-delete-method" {
  authorization = "NONE"
  http_method   = "DELETE"
  resource_id   = aws_api_gateway_resource.product-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "product-delete-integration" {
  http_method             = aws_api_gateway_method.product-delete-method.http_method
  resource_id             = aws_api_gateway_resource.product-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}

###################### /products ######################
resource "aws_api_gateway_resource" "products-resource" {
  parent_id   = aws_api_gateway_rest_api.serverless-api.root_resource_id
  path_part   = "products"
  rest_api_id = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_method" "products-get-method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.products-resource.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
}

resource "aws_api_gateway_integration" "products-get-integration" {
  http_method             = aws_api_gateway_method.products-get-method.http_method
  resource_id             = aws_api_gateway_resource.products-resource.id
  rest_api_id             = aws_api_gateway_rest_api.serverless-api.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.serverless-api.invoke_arn
}
#######################################################

resource "aws_api_gateway_deployment" "deploy-api" {
  rest_api_id = aws_api_gateway_rest_api.serverless-api.id

  #   triggers = {
  #     # NOTE: The configuration below will satisfy ordering considerations,
  #     #       but not pick up all future REST API changes. More advanced patterns
  #     #       are possible, such as using the filesha1() function against the
  #     #       Terraform configuration file(s) or removing the .id references to
  #     #       calculate a hash against whole resources. Be aware that using whole
  #     #       resources will show a difference after the initial implementation.
  #     #       It will stabilize to only change when resources change afterwards.
  #     redeployment = sha1(jsonencode([
  #       aws_api_gateway_resource.health-resource.id,
  #       aws_api_gateway_method.health-get-method.id,
  #       aws_api_gateway_integration.health-get-integration.id,
  #     ]))
  #   }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_api_gateway_resource.health-resource,
    aws_api_gateway_method.health-get-method,
    aws_api_gateway_integration.health-get-integration,
    aws_api_gateway_resource.product-resource,
    aws_api_gateway_method.product-get-method,
    aws_api_gateway_method.product-patch-method,
    aws_api_gateway_method.product-post-method,
    aws_api_gateway_method.product-delete-method,
    aws_api_gateway_integration.product-get-integration,
    aws_api_gateway_integration.product-patch-integration,
    aws_api_gateway_integration.product-post-integration,
    aws_api_gateway_integration.product-delete-integration,
    aws_api_gateway_resource.products-resource,
    aws_api_gateway_method.products-get-method,
    aws_api_gateway_integration.products-get-integration
  ]
}

resource "aws_api_gateway_stage" "stage-api" {
  deployment_id = aws_api_gateway_deployment.deploy-api.id
  rest_api_id   = aws_api_gateway_rest_api.serverless-api.id
  stage_name    = "prod"
}
