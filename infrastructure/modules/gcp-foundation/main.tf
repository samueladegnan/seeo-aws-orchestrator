terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name}-subnet"
  ip_cidr_range = var.subnet_prefix
  region        = var.region
  network       = google_compute_network.this.id
}
