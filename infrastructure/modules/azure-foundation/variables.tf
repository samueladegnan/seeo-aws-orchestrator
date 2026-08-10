variable "name" {
  description = "Name prefix for the Azure foundation resources"
  type        = string
}

variable "location" {
  description = "Azure region for the foundation"
  type        = string
}

variable "address_space" {
  description = "Address space for the Azure virtual network"
  type        = string
}

variable "subnet_prefix" {
  description = "Address prefix for the Azure subnet"
  type        = string
}
