provider "aws" {
  region = "ap-south-1"
}

# ---------------- VPC ----------------
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "main-vpc" }
}

# ---------------- SUBNETS ----------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"
}

# ---------------- INTERNET + NAT ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.eip.id
  depends_on    = [aws_internet_gateway.igw]
}

# ---------------- ROUTING ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "priv1_assoc" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "priv2_assoc" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private_rt.id
}

# ---------------- SECURITY GROUP ----------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- EC2 (JENKINS) ----------------
resource "aws_instance" "jenkins" {
  ami                    = "ami-05d2d839d4f73aafb"
  instance_type          = "c7i-flex.large"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = "KP3"

  root_block_device {
    volume_size = 20      # ✅ 20 GB
    volume_type = "gp3"
  }

  tags = { Name = "Jenkins-Server" }
}

# ---------------- IAM FOR EKS ----------------
resource "aws_iam_role" "eks_role" {
  name = "eks-role-final"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------- EKS CLUSTER ----------------
resource "aws_eks_cluster" "eks" {
  name     = "ekscluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private1.id,
      aws_subnet.private2.id
    ]
  }
}

# ---------------- NODE ROLE ----------------
resource "aws_iam_role" "node_role" {
  name = "eks-node-role-final"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------- NODE GROUP ----------------
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes"
  node_role_arn   = aws_iam_role.node_role.arn

  subnet_ids = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["c7i-flex.large"]
}