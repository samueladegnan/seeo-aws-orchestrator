output "provider" {
  description = "Provider represented by this stack"
  value       = "aws"
}

output "network_id" {
  description = "AWS VPC ID consumed by the AWS adapter"
  value       = aws_vpc.seeo.id
}

output "subnet_ids" {
  description = "AWS subnet IDs consumed by the AWS adapter"
  value       = aws_subnet.seeo[*].id
}

output "security_group_id" {
  description = "AWS security group ID for ephemeral workloads"
  value       = aws_security_group.seeo.id
}

output "workload_identity" {
  description = "AWS instance profile used by ephemeral workloads"
  value       = aws_iam_instance_profile.environment.name
}
