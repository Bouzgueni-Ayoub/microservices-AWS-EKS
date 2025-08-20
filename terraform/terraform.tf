terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "backend-aws-eks-project" 
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
}

