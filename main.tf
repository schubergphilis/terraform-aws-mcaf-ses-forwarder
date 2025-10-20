locals {
  account_id     = data.aws_caller_identity.default.account_id
  account_region = var.region != null ? var.region : data.aws_region.default.region
  bucket_prefix  = length(regexall("/$", var.bucket_prefix)) > 0 ? var.bucket_prefix : "${var.bucket_prefix}/"

  # Remove prefixed @ if present in key name. The lambda catches all mail for a domain when it sees
  # the prefix but the incoming mail rule in SES breaks when it's present, so we strip it out for
  # the incoming mail rule.
  recipient_mapping = {
    for k, v in var.recipient_mapping : startswith(k, "@") ? trimprefix(k, "@") : k => v
  }
}

data "aws_caller_identity" "default" {}

data "aws_region" "default" {}

resource "aws_ses_receipt_rule_set" "default" {
  region        = local.account_region
  rule_set_name = var.ses_rule_set_name
}

resource "aws_ses_active_receipt_rule_set" "default" {
  region        = local.account_region
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
}

resource "aws_ses_receipt_rule" "default" {
  region        = local.account_region
  name          = var.ses_rule_name
  rule_set_name = aws_ses_active_receipt_rule_set.default.rule_set_name
  recipients    = keys(local.recipient_mapping)
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
    module.lambda,
    module.s3_bucket,
  ]
}
