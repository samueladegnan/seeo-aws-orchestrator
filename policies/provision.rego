package seeo

default max_ttl_minutes := 1440
default allowed_providers := ["aws", "azure", "gcp", "oci"]
default allowed_compute_tiers := ["small", "medium", "large"]
default max_concurrent_environments := 10
default max_volume_size_gb := 1000

authorized_regions := {
  "aws": {"us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1"},
  "azure": {"eastus", "westus2", "westeurope", "southeastasia"},
  "gcp": {"us-central1", "us-east1", "europe-west1", "asia-southeast1"},
  "oci": {"us-ashburn-1", "us-phoenix-1", "uk-london-1", "ap-singapore-1"}
}

default allowed_storage_tiers := ["balanced", "performance", "throughput"]

allow if {
  input.provider in data.seeo.allowed_providers
  input.compute_tier in data.seeo.allowed_compute_tiers
  input.ttl_minutes >= 1
  input.ttl_minutes <= data.seeo.max_ttl_minutes
  region_allowed
  input.storage_tier in data.seeo.allowed_storage_tiers
  input.volume_size <= data.seeo.max_volume_size_gb
  input.active_environment_count < data.seeo.max_concurrent_environments
}

region_allowed if not input.region
region_allowed if input.region in data.seeo.authorized_regions[input.provider]

deny contains msg if {
  not input.provider in data.seeo.allowed_providers
  msg := sprintf("Provider %s is not allowed", [input.provider])
}

deny contains msg if {
  input.ttl_minutes < 1
  msg := "TTL must be at least 1 minute"
}

deny contains msg if {
  input.ttl_minutes > data.seeo.max_ttl_minutes
  msg := sprintf("TTL exceeds maximum of %d minutes", [data.seeo.max_ttl_minutes])
}

deny contains msg if {
  not input.compute_tier in data.seeo.allowed_compute_tiers
  msg := sprintf("Compute tier %s is not allowed", [input.compute_tier])
}

deny contains msg if {
  input.region
  not input.region in data.seeo.authorized_regions[input.provider]
  msg := sprintf("Region %s is not allowed for %s", [input.region, input.provider])
}

deny contains msg if {
  not input.storage_tier in data.seeo.allowed_storage_tiers
  msg := sprintf("Storage tier %s is not allowed", [input.storage_tier])
}

deny contains msg if {
  input.volume_size > data.seeo.max_volume_size_gb
  msg := sprintf("Volume size exceeds maximum of %d GB", [data.seeo.max_volume_size_gb])
}

deny contains msg if {
  input.active_environment_count >= data.seeo.max_concurrent_environments
  msg := sprintf("Concurrent environment limit of %d reached", [data.seeo.max_concurrent_environments])
}
