provider "aws" {
  region = "ap-southeast-1"
}

// Create VPC
resource "aws_vpc" "vpc-devops" {
  cidr_block = "10.100.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name: "vpc-devops"
  }
}

// Create Subnet
resource "aws_subnet" "subnet-devops" {
  vpc_id = aws_vpc.vpc-devops.id
  cidr_block = "10.100.16.0/20"
  map_public_ip_on_launch = true
  tags = {
    Name: "subnet-devops"
  }
}

resource "aws_subnet" "subnet-devops-1" {
  vpc_id = aws_vpc.vpc-devops.id
  cidr_block = "10.100.48.0/20"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"
  tags = {
    Name: "subnet-devops"
  }
}

resource "aws_subnet" "subnet-devops-2" {
  vpc_id = aws_vpc.vpc-devops.id
  cidr_block = "10.100.32.0/20"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
    Name: "subnet-devops"
  }
}

// Create Internet Gateway
resource "aws_internet_gateway" "igw-devops" {
  vpc_id = aws_vpc.vpc-devops.id
  tags = {
    Name: "igw-devops"
  }
}

// Create Route table
resource "aws_route_table" "rtb-devpos" {
  vpc_id = aws_vpc.vpc-devops.id
  tags = {
    Name: "rtb-devops"
  }
}

// Add route for route table target to internet gateway
resource "aws_route" "route-devops" {
  route_table_id = aws_route_table.rtb-devpos.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw-devops.id

  depends_on = [ aws_route_table.rtb-devpos ]
}

// Associate Route table to Subnet
resource "aws_route_table_association" "rtb-association-devops" {
  subnet_id = aws_subnet.subnet-devops.id
  route_table_id = aws_route_table.rtb-devpos.id
}

// Associate Route table to Subnet
resource "aws_route_table_association" "rtb-association-devops-1" {
  subnet_id = aws_subnet.subnet-devops-1.id
  route_table_id = aws_route_table.rtb-devpos.id
}

// Associate Route table to Subnet
resource "aws_route_table_association" "rtb-association-devops-2" {
  subnet_id = aws_subnet.subnet-devops-2.id
  route_table_id = aws_route_table.rtb-devpos.id
}

// Create security group
resource "aws_security_group" "sgr-devops" {
  name = "sgr-devops"
  description = "Security group for DevOps"
  vpc_id = aws_vpc.vpc-devops.id

  dynamic "ingress" {
    for_each = toset(var.sgr_rules.ports_in)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Create EC2 Instance for Jenkins and Docker
resource "aws_instance" "ec2-devops" {
  ami = "ami-05548f9cecf47b442"
  instance_type = var.instance_type.t2_micro
  subnet_id = aws_subnet.subnet-devops.id
  key_name = var.keypair
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.sgr-devops.id]
  tags = {
    Name = "ec2-devops"
  }
}

// Create ECR reposiroty
resource "aws_ecr_repository" "ecr-be-devops" {
  name = "backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "ecr-fe-devops" {
  name = "frontend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

// Create EKS cluster
resource "aws_iam_role" "eks-role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-cluster-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks-role.name
}

resource "aws_eks_cluster" "eks-devops" {
  name = "eks-demo"
  role_arn = aws_iam_role.eks-role.arn
  
  vpc_config {
     subnet_ids = [
      aws_subnet.subnet-devops-1.id,
      aws_subnet.subnet-devops-2.id
    ]
  }
}

// Create EKS node group
resource "aws_iam_role" "eks-node-group-role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-node-group-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-node-group-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-node-group-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks-node-group-role.name
}

data "aws_ssm_parameter" "eks-ami-release-version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.eks-devops.version}/amazon-linux-2/recommended/release_version"
}

resource "aws_eks_node_group" "node-group-devops" {
  cluster_name = aws_eks_cluster.eks-devops.name
  node_group_name = "dev-group"
  version = aws_eks_cluster.eks-devops.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks-ami-release-version.value)
  node_role_arn = aws_iam_role.eks-node-group-role.arn
  subnet_ids = [
    aws_subnet.subnet-devops-1.id,
    aws_subnet.subnet-devops-2.id
  ]

  instance_types = [var.instance_type.t2_micro]
  capacity_type = "SPOT"

  scaling_config {
    desired_size = 1
    max_size = 2
    min_size = 1
  }

  update_config {
    max_unavailable = 1
  }

  remote_access {
    ec2_ssh_key = var.keypair
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEBSCSIDriverPolicy
  ]
}