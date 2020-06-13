terraform {
  required_version = "0.12.26"
  backend "s3" {
    bucket = "atlas-terraform-state-dev"
    key    = "covid-tf.state"
    region = "us-east-2"
  }
}
provider "aws" {
  region = "us-east-2"
}
resource "aws_dynamodb_table" "covid-state-table" {
  name         = "CovidState"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "state"
  range_key    = "date"
  attribute {
    name = "state"
    type = "S"
  }
  attribute {
    name = "date"
    type = "N"
  }
}
resource "aws_dynamodb_table" "covid-us-table" {
  name         = "CovidUS"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "date"

  attribute {
    name = "date"
    type = "N"
  }
}
resource "aws_iam_role" "cacheRole" {
  name               = "covidCacheRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": {
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Effect": "Allow"
  }
}
POLICY
}
resource "aws_iam_role" "apiRole" {
  name               = "covidApiRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": {
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Effect": "Allow"
  }
}
POLICY
}
resource "aws_lambda_function" "covidCache" {
  function_name    = "covidCache"
  filename         = "dist/cache.zip"
  handler          = "cache"
  source_code_hash = filebase64("dist/cache.zip")
  role             = "${aws_iam_role.cacheRole.arn}"
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 1
}
resource "aws_lambda_function" "covidAPIv2" {
  function_name    = "covidAPIv2"
  filename         = "dist/api.zip"
  handler          = "api"
  source_code_hash = filebase64("dist/api.zip")
  role             = "${aws_iam_role.apiRole.arn}"
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 1
}
resource "aws_apigatewayv2_api" "covidAPI" {
  name          = "covid-api"
  protocol_type = "HTTP"
}
resource "aws_apigatewayv2_integration" "base" {
  api_id                 = "${aws_apigatewayv2_api.covidAPI.id}"
  integration_type       = "AWS_PROXY"
  description            = "Lambda example"
  integration_method     = "POST"
  integration_uri        = "${aws_lambda_function.covidAPIv2.invoke_arn}"
  payload_format_version = "1.0"
}