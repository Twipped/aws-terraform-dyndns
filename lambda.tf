
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [
        "edgelambda.amazonaws.com",
        "lambda.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "lamda_execution_policy" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = [
      aws_route53_zone.zone.arn
    ]
  }

  statement {
    actions = ["route53:GetChange"]

    resources = [
      "arn:aws:route53:::change/*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    actions = [
      "s3:Get*",
      "s3:List*"
    ]

    resources = [
      aws_s3_bucket.config.arn
    ]
  }
}

resource "aws_iam_role" "dyndns_lamda" {
  name = "${var.site}-dyndns_lamda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Site = var.site
  }
}

resource "aws_iam_role_policy" "dyndns_lamda" {
  name_prefix = "lambda-execution-policy-"
  role        = aws_iam_role.dyndns_lamda.id

  policy = data.aws_iam_policy_document.lamda_execution_policy.json
}

data "archive_file" "dyndns_lamda" {
  type        = "zip"
  output_path = "${path.module}/.terraform/cache/lambda.zip"
  source_file = "${path.module}/lambda.py"
}

resource "aws_lambda_function" "dyndns_lamda" {
  description      = "Managed by Terraform"
  filename         = data.archive_file.dyndns_lamda.output_path
  function_name    = "${var.site}-dyndns"
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.dyndns_lamda.output_base64sha256
  publish          = true
  role             = aws_iam_role.dyndns_lamda.arn
  runtime          = "python3.9"

  environment {
    variables = {
      CONFIG_BUCKET = aws_s3_bucket.config.bucket
      CONFIG_FILE = aws_s3_object.object.key
    }
  }

  tags = {
    Name   = "${var.site}-dyndns"
    Site = var.site
  }
}

# aws_cloudwatch_log_group.dyndns_lamda
resource "aws_cloudwatch_log_group" "dyndns_lamda" {
  name = "/aws/lambda/${aws_lambda_function.dyndns_lamda.function_name}"

  retention_in_days = 14

  tags = {
    Site = var.site,
  }
}