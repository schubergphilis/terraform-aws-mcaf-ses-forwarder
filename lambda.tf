locals {
  kms_key_arn_provided = var.kms_key_arn != null ? ["allow_kms"] : []

  lambda_vars = {
    allow_plus_sign   = var.allow_plus_sign
    bucket_name       = var.bucket_name
    bucket_prefix     = local.bucket_prefix
    from_email        = var.from_email
    recipient_mapping = jsonencode(var.recipient_mapping)
    subject_prefix    = var.subject_prefix
  }
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
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_name}:*",
    ]
  }

  statement {
    sid = "AllowBucketAccessAndSendingEmail"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "ses:SendRawEmail"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/*",
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

  source {
    content  = templatefile("${path.module}/lambda/index.js.tftpl", local.lambda_vars)
    filename = "index.js"
  }
}

module "lambda" {
  #checkov:skip=CKV_AWS_272: This module does not provide support for code-signing
  providers = { aws.lambda = aws.lambda }
  source    = "github.com/schubergphilis/terraform-aws-mcaf-lambda?ref=v0.3.10"

  description      = "Forwards email sent to recipients in the \"${var.ses_rule_set_name}\" SES Rule Set to external addresses"
  filename         = data.archive_file.lambda.output_path
  handler          = "index.handler"
  kms_key_arn      = var.kms_key_arn
  memory_size      = 256
  name             = var.lambda_name
  policy           = data.aws_iam_policy_document.lambda_policy.json
  runtime          = "nodejs18.x"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags             = var.tags
  timeout          = 30
}

resource "aws_lambda_permission" "allow_ses" {
  statement_id   = "GiveSESPermissionToInvokeFunction"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda.name
  principal      = "ses.amazonaws.com"
  source_arn     = "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:receipt-rule-set/${aws_ses_receipt_rule_set.default.rule_set_name}:receipt-rule/*"
  source_account = data.aws_caller_identity.current.account_id
}
