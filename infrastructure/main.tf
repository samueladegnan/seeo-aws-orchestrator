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
  # checkov:skip=CKV2_AWS_11: VPC flow logs are disabled to avoid unnecessary CloudWatch/S3 costs for a demo.
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "seeo-vpc"
  }
}

# Manage the default security group for this VPC so we can remove its default rules.
resource "aws_default_security_group" "seeo_default" {
  vpc_id = aws_vpc.seeo.id
}

resource "aws_internet_gateway" "seeo" {
  vpc_id = aws_vpc.seeo.id

  tags = {
    Name = "seeo-igw"
  }
}

resource "aws_subnet" "seeo" {
  # checkov:skip=CKV_AWS_130: Public IP on launch is required for direct EC2 access in this demo.
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
  # checkov:skip=CKV_AWS_260: Port 80/443 open to the world is intended for public web access in this demo.
  # checkov:skip=CKV_AWS_382: Broad outbound access is acceptable for ephemeral demo instances.
  # checkov:skip=CKV2_AWS_5: Security group is attached dynamically at runtime, not in Terraform.
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
    to_port     = 0
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
  # checkov:skip=CKV_AWS_119: Default AWS-owned encryption key is sufficient for this free-tier demo table.
  # checkov:skip=CKV_AWS_28: Point-in-time recovery is disabled to avoid unnecessary storage costs.
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
    name            = "StatusIndex"
    hash_key        = "status"
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
  # checkov:skip=CKV_AWS_149: Default AWS-owned encryption key is sufficient for this free-tier demo secret.
  # checkov:skip=CKV2_AWS_57: Automatic secret rotation is not required for this demo environment.
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
  # checkov:skip=CKV_AWS_111: EC2 orchestration requires broad write permissions for demo functionality.
  # checkov:skip=CKV_AWS_356: Resource wildcard is required for EC2 lifecycle calls such as RunInstances.
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
  # checkov:skip=CKV_AWS_273: Local IAM user is used for simplicity instead of AWS Identity Center (SSO).
  count = var.create_backend_user ? 1 : 0
  name  = "seeo-backend"
}

resource "aws_iam_user_policy_attachment" "seeo_backend" {
  # checkov:skip=CKV_AWS_40: Direct user policy attachment is acceptable for a single-user demo backend.
  count      = var.create_backend_user ? 1 : 0
  user       = aws_iam_user.seeo_backend[0].name
  policy_arn = aws_iam_policy.seeo_backend[0].arn
}

# -----------------------------------------------------------------------------
# AUDIT LOG TABLE
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "audit_logs" {
  # checkov:skip=CKV_AWS_119: Default AWS-owned encryption key is sufficient for this free-tier demo table.
  # checkov:skip=CKV_AWS_28: Point-in-time recovery is disabled to avoid unnecessary storage costs.
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
    name            = "TimestampIndex"
    hash_key        = "timestamp"
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
  # checkov:skip=CKV_AWS_119: Default AWS-owned encryption key is sufficient for this free-tier demo table.
  # checkov:skip=CKV_AWS_28: Point-in-time recovery is disabled to avoid unnecessary storage costs.
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
  # checkov:skip=CKV_AWS_158: Default AWS-owned encryption key is sufficient for this demo log group.
  # checkov:skip=CKV_AWS_338: 14-day retention is sufficient and avoids long-term storage costs.
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
  # checkov:skip=CKV_AWS_136: Default AES256 server-side encryption is sufficient for this demo repository.
  name                 = "seeo-backend"
  image_tag_mutability = "IMMUTABLE"

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
