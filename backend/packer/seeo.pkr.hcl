# This Packer template is intentionally provider-neutral. Provider-specific image
# baking is performed by the selected cloud adapter's image pipeline.

variable "provider" {
  description = "Cloud provider image pipeline to use"
  type        = string
  default     = "aws"
}

variable "region" {
  description = "Provider region"
  type        = string
  default     = "us-east-1"
}

variable "compute_tier" {
  description = "Normalized SEEO compute tier"
  type        = string
  default     = "small"
}

build {
  name    = "seeo-${var.provider}-${var.compute_tier}"
  sources = []

  provisioner "shell-local" {
    inline = [
      "echo Provider image pipeline selected: ${var.provider}",
      "echo Region: ${var.region}",
      "echo Compute tier: ${var.compute_tier}",
      "echo Use the provider-specific image builder for the selected cloud."
    ]
  }
}
