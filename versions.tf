terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "6.10.0"
      configuration_aliases = [aws.principal_account]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}
