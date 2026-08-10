variable "name" {
  description = "Name prefix for the Azure foundation"
  type        = string
  default     = "seeo-azure"
}

variable "location" {
  description = "Azure region for the foundation"
  type        = string
  default     = "East US"
}

variable "address_space" {
  description = "Address space for the Azure virtual network"
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_prefix" {
  description = "Address prefix for the Azure subnet"
  type        = string
  default     = "10.20.1.0/24"
}
