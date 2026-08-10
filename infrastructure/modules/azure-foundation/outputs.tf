output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.this.name
}

output "virtual_network_id" {
  description = "Azure virtual network ID"
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "Azure subnet ID"
  value       = azurerm_subnet.this.id
}
