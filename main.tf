locals {
  bucket_prefix = length(regexall("/$", var.bucket_prefix)) > 0 ? var.bucket_prefix : "${var.bucket_prefix}/"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = var.ses_rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "default" {
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
}

resource "aws_ses_receipt_rule" "default" {
  name          = var.ses_rule_name
  rule_set_name = aws_ses_active_receipt_rule_set.default.rule_set_name
  recipients    = keys(var.recipient_mapping)
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = var.bucket_name
    object_key_prefix = local.bucket_prefix
    position          = 1
  }

  lambda_action {
    function_arn    = module.lambda.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_lambda_permission.allow_ses,
    module.lambda,
    module.s3_bucket,
  ]
}
