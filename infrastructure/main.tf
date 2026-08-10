terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "seeo" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name              = "seeo-${var.name}"
    "seeo:provider"   = "aws"
    "seeo:managed_by" = "terraform"
  }
}

resource "aws_default_security_group" "seeo_default" {
  vpc_id = aws_vpc.seeo.id
}

resource "aws_internet_gateway" "seeo" {
  vpc_id = aws_vpc.seeo.id
  tags   = { Name = "seeo-${var.name}-igw" }
}

resource "aws_subnet" "seeo" {
  count                   = 2
  vpc_id                  = aws_vpc.seeo.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "seeo-${var.name}-subnet-${count.index + 1}" }
}

resource "aws_route_table" "seeo" {
  vpc_id = aws_vpc.seeo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.seeo.id
  }

  tags = { Name = "seeo-${var.name}-public-rt" }
}

resource "aws_route_table_association" "seeo" {
  count          = 2
  subnet_id      = aws_subnet.seeo[count.index].id
  route_table_id = aws_route_table.seeo.id
}

resource "aws_security_group" "seeo" {
  name_prefix = "seeo-${var.name}-"
  description = "Network boundary for SEEO AWS environments"
  vpc_id      = aws_vpc.seeo.id

  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr != "" ? [var.allowed_ssh_cidr] : []
    content {
      description = "SSH from the operator network"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "HTTPS application traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Provider API and application egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name            = "seeo-${var.name}-environment-sg"
    "seeo:provider" = "aws"
  }
}

# The Rails control plane owns lifecycle state. This role is an optional
# workload identity boundary for the AWS adapter and is not a database role.
data "aws_iam_policy_document" "environment_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "environment" {
  name               = "seeo-${var.name}-environment-role"
  assume_role_policy = data.aws_iam_policy_document.environment_trust.json
  tags               = { Name = "seeo-${var.name}-environment-role" }
}

resource "aws_iam_instance_profile" "environment" {
  name = "seeo-${var.name}-environment-profile"
  role = aws_iam_role.environment.name
}
