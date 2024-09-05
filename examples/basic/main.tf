provider "aws" {
  region = "eu-west-1"
}

module "ses-root-accounts-mail-forward" {
  #checkov:skip=CKV_AWS_19: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module is encrypted with KMS.
  #checkov:skip=CKV_AWS_145: False positive: https://github.com/bridgecrewio/checkov/issues/3847. The S3 bucket created by this module is encrypted with KMS.
  #checkov:skip=CKV_AWS_272: This module does not support lambda code signing at the moment
  providers = { aws = aws, aws.lambda = aws }

  source            = "../.."
  bucket_name       = "ses-forwarder-bucket"
  from_email        = "example@mail.something"
  recipient_mapping = {}
}
