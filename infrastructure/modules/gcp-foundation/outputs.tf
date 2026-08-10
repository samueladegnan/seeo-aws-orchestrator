output "network_id" {
  description = "Google Cloud VPC network ID"
  value       = google_compute_network.this.id
}

output "subnetwork_id" {
  description = "Google Cloud subnetwork ID"
  value       = google_compute_subnetwork.this.id
}
