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

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "seeo" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "seeo-vpc"
  }
}

resource "aws_internet_gateway" "seeo" {
  vpc_id = aws_vpc.seeo.id

  tags = {
    Name = "seeo-igw"
  }
}

resource "aws_subnet" "seeo" {
  count                   = 2
  vpc_id                  = aws_vpc.seeo.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "seeo-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "seeo" {
  vpc_id = aws_vpc.seeo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.seeo.id
  }

  tags = {
    Name = "seeo-public-rt"
  }
}

resource "aws_route_table_association" "seeo" {
  count          = 2
  subnet_id      = aws_subnet.seeo[count.index].id
  route_table_id = aws_route_table.seeo.id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "seeo" {
  name_prefix = "seeo-ec2-"
  description = "Allow SSH and ephemeral application traffic"
  vpc_id      = aws_vpc.seeo.id

  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr != "" ? [var.allowed_ssh_cidr] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port       = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "seeo-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM Role & INSTANCE PROFILE
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seeo_ec2" {
  name               = "seeo-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "seeo-ec2-role"
  }
}

resource "aws_iam_role_policy" "seeo_ec2" {
  name = "seeo-ec2-policy"
  role = aws_iam_role.seeo_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.seeo.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "seeo_ec2" {
  name = "seeo-ec2-instance-profile"
  role = aws_iam_role.seeo_ec2.name
}

# -----------------------------------------------------------------------------
# DynamoDB TABLE
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "environments" {
  name         = var.environments_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name     = "StatusIndex"
    hash_key = "status"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = var.environments_table
  }
}

# -----------------------------------------------------------------------------
# SECRETS MANAGER
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "seeo" {
  name        = var.secrets_secret_name
  description = "Runtime credentials for SEEO-provisioned environments"
}

resource "aws_secretsmanager_secret_version" "seeo" {
  secret_id = aws_secretsmanager_secret.seeo.id
  secret_string = jsonencode({
    database_password = "change-me-in-production"
    api_key           = "change-me-in-production"
  })
}

# -----------------------------------------------------------------------------
# BACKEND APPLICATION POLICY (for local/dev runner)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "seeo_backend" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeSubnets",
      "ec2:DescribeAvailabilityZones",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:DescribeVolumes",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.environments.arn]
  }
}

resource "aws_iam_policy" "seeo_backend" {
  count       = var.create_backend_user ? 1 : 0
  name        = "seeo-backend-policy"
  description = "Permissions for the SEEO backend to orchestrate EC2/EBS resources"
  policy      = data.aws_iam_policy_document.seeo_backend.json
}

resource "aws_iam_user" "seeo_backend" {
  count = var.create_backend_user ? 1 : 0
  name  = "seeo-backend"
}

resource "aws_iam_user_policy_attachment" "seeo_backend" {
  count      = var.create_backend_user ? 1 : 0
  user       = aws_iam_user.seeo_backend[0].name
  policy_arn = aws_iam_policy.seeo_backend[0].arn
}

# -----------------------------------------------------------------------------
# AUDIT LOG TABLE
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "audit_logs" {
  name         = var.audit_log_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  global_secondary_index {
    name     = "TimestampIndex"
    hash_key = "timestamp"
    projection_type = "ALL"
  }

  tags = {
    Name = var.audit_log_table
  }
}

# -----------------------------------------------------------------------------
# COST SNAPSHOTS TABLE
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "cost_snapshots" {
  name         = var.cost_snapshots_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = var.cost_snapshots_table
  }
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "seeo" {
  name              = "/seeo/backend"
  retention_in_days = 14

  tags = {
    Name = "seeo-backend-logs"
  }
}

# -----------------------------------------------------------------------------
# ECR REPOSITORY FOR BACKEND CONTAINER
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "seeo" {
  name                 = "seeo-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "seeo-backend"
  }
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR ECS / APP RUNNER BACKEND DEPLOYMENT
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "seeo_backend_task_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seeo_backend_task" {
  name               = "seeo-backend-task-role"
  assume_role_policy = data.aws_iam_policy_document.seeo_backend_task_trust.json

  tags = {
    Name = "seeo-backend-task-role"
  }
}
