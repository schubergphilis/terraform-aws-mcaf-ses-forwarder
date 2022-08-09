data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid     = "AllowSESPuts"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    resources = ["arn:aws:s3:::${var.bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "s3_bucket" {
  source         = "github.com/schubergphilis/terraform-aws-mcaf-s3?ref=v0.6.1"
  name           = var.bucket_name
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = var.bucket_lifecycle_rules
  policy         = data.aws_iam_policy_document.logs_bucket.json
  tags           = var.tags
}
