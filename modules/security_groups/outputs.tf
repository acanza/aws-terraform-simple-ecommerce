output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "ec2_security_group_arn" {
  description = "ARN of the EC2 security group"
  value       = aws_security_group.ec2.arn
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = aws_security_group.rds.arn
}

output "app_runner_security_group_id" {
  description = "ID of the App Runner VPC Connector security group"
  value       = aws_security_group.app_runner.id
}

output "app_runner_security_group_arn" {
  description = "ARN of the App Runner VPC Connector security group"
  value       = aws_security_group.app_runner.arn
}

output "security_groups" {
  description = "Map of all security group IDs"
  value = {
    ec2        = aws_security_group.ec2.id
    rds        = aws_security_group.rds.id
    app_runner = aws_security_group.app_runner.id
  }
}
