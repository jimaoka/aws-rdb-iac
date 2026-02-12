generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }

      backend "s3" {
        bucket         = "tfstate-ny3mq4w6"
        dynamodb_table = "terraform-lock"
        key            = "aws-rdb-iac/terraform.tfstate"
        region         = "ap-northeast-1"
        encrypt        = true
      }
    }

    provider "aws" {
      region = var.aws_region

      default_tags {
        tags = {
          Environment = var.environment
          ManagedBy   = "Terraform"
        }
      }
    }
  EOF
}

terraform {

}

generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "aws_region" {
      description = "AWS region"
      type        = string
      default     = "ap-northeast-1"
    }

    variable "environment" {
      description = "Environment name"
      type        = string
      default     = "dev"
    }
  EOF
}
