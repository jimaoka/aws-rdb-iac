remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "tfstate-ny3mq4w6"
    dynamodb_table = "terraform-lock"
    key            = "aws-rdb-iac/${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
  }
}

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
