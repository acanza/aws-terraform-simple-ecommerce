output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance (if associated)"
  value       = aws_instance.main.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.main.public_dns
}

output "primary_network_interface_id" {
  description = "The ID of the primary network interface"
  value       = aws_instance.main.primary_network_interface_id
}

output "security_group_id" {
  description = "The security group ID associated with the instance"
  value       = one(aws_instance.main.vpc_security_group_ids)
}

output "instance_state" {
  description = "The state of the instance (running, stopped, etc.)"
  value       = aws_instance.main.instance_state
}
