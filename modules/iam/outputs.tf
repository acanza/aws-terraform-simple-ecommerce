output "ec2_instance_profile_name" {
  description = "IAM instance profile name for EC2 attachment"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_instance_profile_arn" {
  description = "IAM instance profile ARN for EC2 attachment"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "ec2_instance_role_name" {
  description = "IAM role name for EC2 instances"
  value       = aws_iam_role.ec2_instance_role.name
}

output "ec2_instance_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "terraform_user_name" {
  description = "IAM username for Terraform/DevOps infrastructure management"
  value       = aws_iam_user.terraform.name
}

output "terraform_user_arn" {
  description = "IAM user ARN for Terraform/DevOps infrastructure management"
  value       = aws_iam_user.terraform.arn
}

output "ssh_user_name" {
  description = "IAM username for SSH/SSM session access to EC2 (if enabled)"
  value       = try(aws_iam_user.ssh_user[0].name, null)
}

output "ssh_user_arn" {
  description = "IAM user ARN for SSH/SSM session access (if enabled)"
  value       = try(aws_iam_user.ssh_user[0].arn, null)
}

output "read_only_group_name" {
  description = "IAM group name for read-only access"
  value       = aws_iam_group.read_only.name
}

output "read_only_group_arn" {
  description = "IAM group ARN for read-only access"
  value       = aws_iam_group.read_only.arn
}
