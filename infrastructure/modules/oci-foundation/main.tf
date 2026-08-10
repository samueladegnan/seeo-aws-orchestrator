terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.address_space]
  display_name   = var.name
}

resource "oci_core_subnet" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.subnet_prefix
  display_name   = "${var.name}-subnet"
}
