locals {
  kms_key_arn_provided = var.kms_key_arn != null ? ["allow_kms"] : []
}

resource "aws_sqs_queue" "lambda_dlq" {
  name                              = "${var.lambda_name}-dlq"
  kms_data_key_reuse_period_seconds = var.kms_key_arn != null ? 300 : null
  kms_master_key_id                 = var.kms_key_arn
  message_retention_seconds         = 1209600 # 14 days
  tags                              = var.tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "AllowLogManagement"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${local.account_region}:${local.account_id}:log-group:/aws/lambda/${var.lambda_name}:*",
    ]
  }

  statement {
    sid = "AllowBucketAccessAndSendingEmail"
    actions = [
      "s3:GetObject",
      "ses:SendRawEmail",
      "ses:SendEmail"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
      "arn:aws:ses:${local.account_region}:${local.account_id}:identity/*",
    ]
  }

  statement {
    sid = "AllowDLQAccess"
    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.lambda_dlq.arn
    ]
  }

  dynamic "statement" {
    for_each = local.kms_key_arn_provided

    content {
      sid = "AllowKMSDecrypt"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]

      resources = [
        var.kms_key_arn
      ]
    }
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source_dir  = "${path.module}/lambda/"
}

module "lambda" {
  #checkov:skip=CKV_AWS_272: This module does not provide support for code-signing
  source  = "schubergphilis/mcaf-lambda/aws"
  version = "~> 3.0.0"

  region                 = local.account_region
  dead_letter_target_arn = aws_sqs_queue.lambda_dlq.arn
  description            = "Forwards email sent to recipients in the \"${var.ses_rule_set_name}\" SES Rule Set to external addresses"
  filename               = data.archive_file.lambda.output_path
  handler                = "index.handler"
  kms_key_arn            = var.kms_key_arn
  memory_size            = 256
  name                   = var.lambda_name
  runtime                = "nodejs24.x"
  source_code_hash       = data.archive_file.lambda.output_base64sha256
  tags                   = var.tags
  timeout                = 30

  execution_role = {
    create_policy = true
    policy = data.aws_iam_policy_document.lambda_policy.json
  }

  environment = {
    ALLOW_PLUS_SIGN   = var.allow_plus_sign
    BUCKET_NAME       = var.bucket_name
    BUCKET_PREFIX     = local.bucket_prefix
    FROM_EMAIL        = var.from_email
    RECIPIENT_MAPPING = jsonencode(var.recipient_mapping)
    SUBJECT_PREFIX    = var.subject_prefix
  }
}

resource "aws_lambda_permission" "allow_ses" {
  region         = local.account_region
  statement_id   = "GiveSESPermissionToInvokeFunction"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda.name
  principal      = "ses.amazonaws.com"
  source_arn     = "arn:aws:ses:${local.account_region}:${local.account_id}:receipt-rule-set/${aws_ses_receipt_rule_set.default.rule_set_name}:receipt-rule/*"
  source_account = local.account_id
}
