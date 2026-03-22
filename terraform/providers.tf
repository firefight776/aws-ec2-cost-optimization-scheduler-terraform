terraform {
  required_version = ">= 1.5.0"

  cloud {
    organization = "aws-landing-zone"

    workspaces {
      name = "aws-ec2-cost-optimization-scheduler-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}