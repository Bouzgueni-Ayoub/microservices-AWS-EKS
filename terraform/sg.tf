# ---------------------------
# Jenkins Security Group
# ---------------------------
resource "aws_security_group" "jenkings_sg" {
  name        = "jenkings_sg"
  description = "Security group for Jenkins EC2 instance"
  vpc_id      = aws_vpc.eks_vpc.id

  # Allow Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# EKS Node Group Security Group
# ---------------------------
resource "aws_security_group" "eks_node_sg" {
  name        = "eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.eks_vpc.id

  # Allow all traffic between nodes in the same SG
  ingress {
    description = "Inter-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow NodePort services from ELB
  ingress {
    description = "ELB to NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP traffic from Load Balancer
  ingress {
    description = "HTTP from ELB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS egress for UDP (CoreDNS)
  egress {
    description = "DNS UDP to CoreDNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["172.20.0.0/16"]
  }

  # DNS egress for TCP (fallback queries)
  egress {
    description = "DNS TCP to CoreDNS"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["172.20.0.0/16"]
  }

  # Allow SSH (optional, for node troubleshooting)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow nodes to reach cluster IPs over HTTPS
  egress {
    description = "Nodes to cluster IPs (443)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.20.0.0/16"]
  }

  tags = {
    Name = "eks-node-sg"
  }
}

# ---------------------------
# Extra Control Plane → Node Rules
# ---------------------------

# Allow control plane to access kubelet on port 10250
resource "aws_security_group_rule" "allow_cp_to_nodes_10250" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  description              = "Control plane to node kubelet (10250)"
}

# Allow control plane to connect to nodes over HTTPS (443)
resource "aws_security_group_rule" "allow_cp_to_nodes_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  description              = "Control plane to node (443)"
}
