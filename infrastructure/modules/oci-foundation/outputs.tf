output "vcn_id" {
  description = "OCI virtual cloud network ID"
  value       = oci_core_vcn.this.id
}

output "subnet_id" {
  description = "OCI subnet ID"
  value       = oci_core_subnet.this.id
}
