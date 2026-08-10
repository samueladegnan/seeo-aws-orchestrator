terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "foundation" {
  source = "../../modules/gcp-foundation"

  name          = var.name
  region        = var.region
  subnet_prefix = var.subnet_prefix
}

output "provider" { value = "gcp" }
output "network_id" { value = module.foundation.network_id }
output "subnet_id" { value = module.foundation.subnetwork_id }
output "project_id" { value = var.project_id }
