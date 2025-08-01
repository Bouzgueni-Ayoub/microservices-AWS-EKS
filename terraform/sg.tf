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
  ingress {
    from_port   = 80
    to_port     = 80
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
