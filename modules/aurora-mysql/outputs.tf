output "cluster_endpoint" {
  description = "Cluster writer endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Cluster reader endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Cluster port"
  value       = aws_rds_cluster.this.port
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "cluster_instances" {
  description = "List of cluster instance identifiers"
  value       = aws_rds_cluster_instance.this[*].identifier
}

output "parameter_group_name" {
  description = "Cluster parameter group name"
  value       = aws_rds_cluster_parameter_group.this.name
}
