output "db_instance_endpoint" {
  description = "Primary DB instance endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Primary DB instance hostname"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Primary DB instance port"
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "parameter_group_name" {
  description = "DB parameter group name"
  value       = aws_db_parameter_group.this.name
}

output "read_replica_endpoints" {
  description = "List of read replica endpoints"
  value       = aws_db_instance.read_replica[*].endpoint
}
