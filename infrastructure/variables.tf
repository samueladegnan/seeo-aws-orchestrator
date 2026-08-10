variable "name" {
  description = "Name prefix shared with the SEEO AWS adapter"
  type        = string
  default     = "aws"
}

variable "aws_region" {
  description = "AWS region for the provider foundation"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS provider network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "Optional operator CIDR allowed to reach SSH"
  type        = string
  default     = ""
}
