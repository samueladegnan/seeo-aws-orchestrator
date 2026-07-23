output "vpc_id" {
  description = "ID of the SEEO VPC"
  value       = aws_vpc.seeo.id
}

output "subnet_ids" {
  description = "IDs of the SEEO public subnets"
  value       = aws_subnet.seeo[*].id
}

output "security_group_id" {
  description = "ID of the SEEO EC2 security group"
  value       = aws_security_group.seeo.id
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile for SEEO environments"
  value       = aws_iam_instance_profile.seeo_ec2.name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB environments table"
  value       = aws_dynamodb_table.environments.name
}

output "secrets_manager_secret_name" {
  description = "Name of the runtime credentials secret"
  value       = aws_secretsmanager_secret.seeo.name
}
