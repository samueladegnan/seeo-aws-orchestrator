terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }
}

provider "oci" {
  region = var.region
}

module "foundation" {
  source = "../../modules/oci-foundation"

  name           = var.name
  compartment_id = var.compartment_id
  address_space  = var.address_space
  subnet_prefix  = var.subnet_prefix
}

output "provider" { value = "oci" }
output "network_id" { value = module.foundation.vcn_id }
output "subnet_id" { value = module.foundation.subnet_id }
output "compartment_id" { value = var.compartment_id }
