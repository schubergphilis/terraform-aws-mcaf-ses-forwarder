provider "aws" {
  region = "eu-west-1"
}

module "ses-root-accounts-mail-forward" {
  #checkov:skip=CKV_AWS_272: This module does not support lambda code signing at the moment
  source            = "../.."
  bucket_name       = "ses-forwarder-bucket"
  from_email        = "example@mail.something"
  recipient_mapping = {}
}
