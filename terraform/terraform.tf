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

data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.eks_cluster.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
