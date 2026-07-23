variable "aws_region" {
  description = "AWS region to deploy SEEO resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the SEEO VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into SEEO environments (leave empty to disable SSH)"
  type        = string
  default     = ""
}

variable "environments_table" {
  description = "DynamoDB table name for tracking environments"
  type        = string
  default     = "seeo-environments"
}

variable "secrets_secret_name" {
  description = "AWS Secrets Manager secret name for runtime credentials"
  type        = string
  default     = "seeo/runtime/credentials"
}

variable "create_backend_user" {
  description = "Whether to create an dedicated IAM user for the backend runner"
  type        = bool
  default     = true
}
