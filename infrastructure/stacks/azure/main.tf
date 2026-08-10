terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "foundation" {
  source = "../../modules/azure-foundation"

  name          = var.name
  location      = var.location
  address_space = var.address_space
  subnet_prefix = var.subnet_prefix
}

output "provider" { value = "azure" }
output "network_id" { value = module.foundation.virtual_network_id }
output "subnet_id" { value = module.foundation.subnet_id }
output "resource_group_name" { value = module.foundation.resource_group_name }
