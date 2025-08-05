# EKS CLUSTER
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet_1a.id,
      aws_subnet.public_subnet_1b.id,
      aws_subnet.private_subnet_1a.id,
      aws_subnet.private_subnet_1b.id
    ]
    
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role_attach
  ]
}

# EKS NODE GROUP

data "aws_ami" "eks_worker_ami" {
  most_recent = true

  owners = ["602401143452"] # Amazon EKS AMI owner

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.29-v*"] # Replace with your K8s version
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.private_subnet_1a.id,aws_subnet.private_subnet_1b.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = "$Latest"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}

resource "aws_launch_template" "eks_node_template" {
  name_prefix   = "eks-node-"
  image_id      = data.aws_ami.eks_worker_ami.id
  instance_type = "t3.medium"

  vpc_security_group_ids = [aws_security_group.eks_node_sg.id,
                            aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id 
    ]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    /etc/eks/bootstrap.sh ${aws_eks_cluster.eks_cluster.name}
  EOT
  )

  lifecycle {
    create_before_destroy = true
  }
}

# EKS ADDONS 
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "kube-proxy"
  addon_version            = "v1.33.0-eksbuild.2" 
  service_account_role_arn = null  # kube-proxy doesn't need a custom SA
  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}


# TEMPORARY 

resource "aws_eks_node_group" "eks_node_group_public" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group-public"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.eks_node_template_public.id
    version = "$Latest"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}
resource "aws_launch_template" "eks_node_template_public" {
  name_prefix   = "eks-node-public-"
  image_id      = data.aws_ami.eks_worker_ami.id
  instance_type = "t3.medium"
  key_name      = "key_pair"  # 👈 Your EC2 key pair name

  vpc_security_group_ids = [aws_security_group.eks_node_sg.id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    /etc/eks/bootstrap.sh ${aws_eks_cluster.eks_cluster.name}
  EOT
  )

  lifecycle {
    create_before_destroy = true
  }
}
