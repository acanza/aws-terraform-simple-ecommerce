output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint (address:port)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_address" {
  description = "RDS instance endpoint address"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_resource_id" {
  description = "RDS instance resource ID"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group"
  value       = aws_db_subnet_group.main.id
}

output "db_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "Master username for RDS database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "engine_version" {
  description = "PostgreSQL engine version"
  value       = aws_db_instance.main.engine_version
}

output "instance_class" {
  description = "RDS instance class"
  value       = aws_db_instance.main.instance_class
}

output "allocated_storage" {
  description = "Allocated storage in GB"
  value       = aws_db_instance.main.allocated_storage
}

output "multi_az" {
  description = "Whether Multi-AZ is enabled"
  value       = aws_db_instance.main.multi_az
}
