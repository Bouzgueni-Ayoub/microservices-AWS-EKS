# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true   # Needed for internal DNS resolution (CoreDNS)
  enable_dns_hostnames = true   # Required for public/private hostnames in VPC

  tags = {
    Name = "Main VPC"
  }
}

# ---------------------------
# Subnets
# ---------------------------

# Private subnet (AZ 1b) for workloads (no public IPs)
resource "aws_subnet" "private_subnet_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-central-1b"

  tags = {
    Name                              = "eks-private-subnet-1b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}

# Private subnet (AZ 1a)
resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-central-1a"

  tags = {
    Name                              = "eks-private-subnet-1a"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}

# Public subnet (AZ 1a) for LB / NAT
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name                          = "eks-public-subnet-1a"
    "kubernetes.io/role/elb"      = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}

# Public subnet (AZ 1b)
resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b"

  tags = {
    Name                          = "eks-public-subnet-1b"
    "kubernetes.io/role/elb"      = "1"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
}

# ---------------------------
# Internet Gateway
# ---------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "main-igw" }
}

# ---------------------------
# NAT Gateways (1 per AZ)
# ---------------------------

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_1a" {
  tags = { Name = "nat-eip-1a" }
}
resource "aws_eip" "nat_eip_1b" {
  tags = { Name = "nat-eip-1b" }
}

# NAT Gateway in public subnet 1a
resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_eip_1a.id
  subnet_id     = aws_subnet.public_subnet_1a.id
  tags = { Name = "nat_1a" }
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway in public subnet 1b
resource "aws_nat_gateway" "nat_1b" {
  allocation_id = aws_eip.nat_eip_1b.id
  subnet_id     = aws_subnet.public_subnet_1b.id
  tags = { Name = "nat_1b" }
  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------
# Public Route Table
# ---------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"    # Route all internet-bound traffic to IGW
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-route-table" }
}

# Public subnet associations
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------------------
# Private Route Tables
# ---------------------------

# Private route table for AZ 1a
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"    # Internet via NAT
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  tags = { Name = "private-route-table" }
}

# Private route table for AZ 1b
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }

  tags = { Name = "private-route-table" }
}

# Private subnet associations
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_rt_a.id
}
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_1b.id
  route_table_id = aws_route_table.private_rt_b.id
}
