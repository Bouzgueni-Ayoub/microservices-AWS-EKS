terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket = "backend-aws-eks-project" # Change to the name of the bucket created for the backend
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
}

