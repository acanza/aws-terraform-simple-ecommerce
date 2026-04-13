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

output "security_groups" {
  description = "Map of all security group IDs"
  value = {
    ec2 = aws_security_group.ec2.id
    rds = aws_security_group.rds.id
  }
}
