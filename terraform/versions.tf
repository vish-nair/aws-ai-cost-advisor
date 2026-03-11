terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }

  backend "s3" {
    # Configure via -backend-config or environment variables
    # bucket         = "your-tfstate-bucket"
    # key            = "aws-ai-cost-advisor/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-ai-cost-advisor"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
