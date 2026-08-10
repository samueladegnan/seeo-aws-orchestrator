variable "name" {
  description = "Name prefix for the Google Cloud foundation"
  type        = string
}

variable "region" {
  description = "Google Cloud region for the foundation"
  type        = string
}

variable "subnet_prefix" {
  description = "Address prefix for the Google Cloud subnet"
  type        = string
}
