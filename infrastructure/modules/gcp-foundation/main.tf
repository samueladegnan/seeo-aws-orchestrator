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

resource "google_compute_firewall" "this" {
  name    = "${var.name}-internal"
  network = google_compute_network.this.id

  target_tags = ["seeo-managed"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = [var.subnet_prefix]
}

resource "google_compute_subnetwork" "this" {
  name                     = "${var.name}-subnet"
  ip_cidr_range            = var.subnet_prefix
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
