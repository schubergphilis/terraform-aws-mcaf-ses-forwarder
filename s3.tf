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
      values   = [local.account_id]
    }
  }
}

module "s3_bucket" {
  #checkov:skip=CKV_AWS_19: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module supports encryption with KMS.
  #checkov:skip=CKV_AWS_145: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module support encryption with KMS.
  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 2.0.0"

  region         = local.account_region
  name           = var.bucket_name
  kms_key_arn    = var.kms_key_arn
  lifecycle_rule = var.bucket_lifecycle_rules
  policy         = data.aws_iam_policy_document.logs_bucket.json
  tags           = var.tags
}
