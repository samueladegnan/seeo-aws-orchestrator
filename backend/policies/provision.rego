package seeo

default allow := false

default max_ttl_minutes := 1440

default max_concurrent_environments := 10

default max_volume_size_gb := 1000

default allowed_instance_types := ["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small", "m6i.large", "m5.large", "m5.xlarge", "c5.large"]

default allowed_regions := ["us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1"]

default allowed_volume_types := ["gp3", "io2", "st1"]

allow if {
    input.ttl_minutes <= data.seeo.max_ttl_minutes
    input.instance_type in data.seeo.allowed_instance_types
    region_allowed
    volume_allowed
    volume_size_allowed
    input.ttl_minutes >= 1
    input.active_environment_count < data.seeo.max_concurrent_environments
}

region_allowed if {
    not input.region
}

region_allowed if {
    input.region in data.seeo.allowed_regions
}

volume_allowed if {
    not input.volume_type
}

volume_allowed if {
    input.volume_type in data.seeo.allowed_volume_types
}

volume_size_allowed if {
    not input.volume_size
}

volume_size_allowed if {
    input.volume_size <= data.seeo.max_volume_size_gb
}

deny contains msg if {
    input.ttl_minutes < 1
    msg := "TTL must be at least 1 minute"
}

deny contains msg if {
    input.ttl_minutes > data.seeo.max_ttl_minutes
    msg := sprintf("TTL %d minutes exceeds maximum %d", [input.ttl_minutes, data.seeo.max_ttl_minutes])
}

deny contains msg if {
    not input.instance_type in data.seeo.allowed_instance_types
    msg := sprintf("Instance type %s is not allowed", [input.instance_type])
}

deny contains msg if {
    input.region
    not input.region in data.seeo.allowed_regions
    msg := sprintf("Region %s is not allowed", [input.region])
}

deny contains msg if {
    input.volume_type
    not input.volume_type in data.seeo.allowed_volume_types
    msg := sprintf("Volume type %s is not allowed", [input.volume_type])
}

deny contains msg if {
    input.volume_size > data.seeo.max_volume_size_gb
    msg := sprintf("Volume size exceeds maximum of %d GB", [data.seeo.max_volume_size_gb])
}

deny contains msg if {
    input.active_environment_count >= data.seeo.max_concurrent_environments
    msg := sprintf("Concurrent environment limit of %d reached", [data.seeo.max_concurrent_environments])
}
