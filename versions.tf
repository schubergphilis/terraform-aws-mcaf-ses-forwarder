terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      configuration_aliases = [aws, aws.lambda]
      source                = "hashicorp/aws"
    }
  }
}
