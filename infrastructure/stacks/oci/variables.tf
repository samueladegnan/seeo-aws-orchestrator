variable "region" {
  description = "OCI region for the foundation"
  type        = string
  default     = "us-ashburn-1"
}

variable "name" {
  description = "Name prefix for the OCI foundation"
  type        = string
  default     = "seeo-oci"
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "address_space" {
  description = "Address space for the OCI VCN"
  type        = string
  default     = "10.40.0.0/16"
}

variable "subnet_prefix" {
  description = "Address prefix for the OCI subnet"
  type        = string
  default     = "10.40.1.0/24"
}
