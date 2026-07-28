package seeo

default allow := false

default max_ttl_minutes := 1440

default allowed_instance_types := ["t3.micro", "t3.small", "t3.medium", "t2.micro", "t2.small", "m6i.large"]

allow if {
    input.ttl_minutes <= data.seeo.max_ttl_minutes
    input.instance_type in data.seeo.allowed_instance_types
}

deny contains msg if {
    input.ttl_minutes > data.seeo.max_ttl_minutes
    msg := sprintf("TTL %d minutes exceeds maximum %d", [input.ttl_minutes, data.seeo.max_ttl_minutes])
}

deny contains msg if {
    not input.instance_type in data.seeo.allowed_instance_types
    msg := sprintf("Instance type %s is not allowed", [input.instance_type])
}
