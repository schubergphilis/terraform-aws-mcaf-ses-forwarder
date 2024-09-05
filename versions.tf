terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      configuration_aliases = [aws, aws.lambda]
      source                = "hashicorp/aws"
      version               = ">= 4.9.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}
