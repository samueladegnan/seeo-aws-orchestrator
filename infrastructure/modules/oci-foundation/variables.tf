variable "name" {
  description = "Name prefix for the Oracle Cloud foundation"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID for the foundation"
  type        = string
}

variable "address_space" {
  description = "Address space for the OCI VCN"
  type        = string
}

variable "subnet_prefix" {
  description = "Address prefix for the OCI subnet"
  type        = string
}
