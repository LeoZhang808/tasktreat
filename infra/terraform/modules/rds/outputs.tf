output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "RDS instance ARN."
  value       = aws_db_instance.this.arn
}

output "rds_endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance."
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "DNS address of the RDS instance, without port."
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "Listening port for the RDS instance."
  value       = aws_db_instance.this.port
}

output "rds_database_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "rds_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "rds_security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}
