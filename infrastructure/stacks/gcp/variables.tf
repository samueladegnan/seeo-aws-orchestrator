variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "name" {
  description = "Name prefix for the Google Cloud foundation"
  type        = string
  default     = "seeo-gcp"
}

variable "region" {
  description = "Google Cloud region for the foundation"
  type        = string
  default     = "us-central1"
}

variable "subnet_prefix" {
  description = "Address prefix for the Google Cloud subnet"
  type        = string
  default     = "10.30.1.0/24"
}
