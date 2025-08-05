resource "aws_vpc" "eks_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Main VPC"
  }
}
resource "aws_subnet" "private_subnet_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone= "eu-central-1b"
  tags = {
    Name                            = "eks-private-subnet-1b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}
resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone= "eu-central-1a"
  tags = {
    Name                            = "eks-private-subnet-1a"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone= "eu-central-1a"
  tags = {
    Name                    = "eks-public-subnet-1a"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone= "eu-central-1b"
  tags = {
    Name                    = "eks-public-subnet-1b"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip_1a" {
  tags = {
    Name = "nat-eip-1a"
  }
}
resource "aws_eip" "nat_eip_1b" {
  tags = {
    Name = "nat-eip-1b"
  }
}

# Create NAT Gateway (in public subnet)
resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_eip_1a.id
  subnet_id     = aws_subnet.public_subnet_1a.id

  tags = {
    Name = "nat_1a"
  }

  depends_on = [aws_internet_gateway.igw]
  
}
resource "aws_nat_gateway" "nat_1b" {
  allocation_id = aws_eip.nat_eip_1b.id
  subnet_id     = aws_subnet.public_subnet_1b.id

  tags = {
    Name = "nat_1b"
  }

  depends_on = [aws_internet_gateway.igw]
  
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_rt.id
}
# Private Route Tables
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  tags = {
    Name = "private-route-table"
  }
}
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }

  tags = {
    Name = "private-route-table"
  }
}
# Associate private subnets with private route table
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_rt_a.id
}
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_1b.id
  route_table_id = aws_route_table.private_rt_b.id
}
