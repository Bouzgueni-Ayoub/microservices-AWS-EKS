# JENKINGS
resource "aws_security_group" "jenkings_sg" {
  name        = "jenkings_sg"
  description = "Security group for jenkings"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
             # SSH
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
}

# EKS NODE GROUP 

resource "aws_security_group" "eks_node_sg" {
  name        = "eks-node-sg"
  description = "Security group for EKS node group"
  vpc_id      = aws_vpc.eks_vpc.id

  # Allow inter-node communication
  ingress {
    description = "Allow all traffic from other nodes in the same SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true # CRUCIAL
  }

  # Allow traffic from ELB to NodePorts
  ingress {
    description = "Allow traffic from ELB to NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow inbound HTTP traffic from Load Balancer (e.g. ALB)
  ingress {
  description = "Allow HTTP traffic from ELB"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }


  # Outbound access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-node-sg"
  }
}
# FIX number 2 for dns issue 
resource "aws_security_group_rule" "allow_cp_to_nodes_10250" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id #This refers to the security group created by AWS 
  description              = "EKS control plane to node kubelet"
}