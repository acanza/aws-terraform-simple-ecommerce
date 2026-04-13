# EC2 Module

Deploys a cost-optimized EC2 instance designed for minimal expenses while maintaining functionality.

## Features

- **Cost Optimized**: Uses `t4g.micro` (AWS Graviton, eligible for free tier) by default
- **Simple Configuration**: Minimal resource footprint
- **Latest Amazon Linux 2**: Automatically selects latest AL2 AMI for the architecture
- **Secure by Default**: IMDSv2 enforcement
- **Public Subnet Ready**: Can be deployed to public or private subnets
- **Flexible**: Easy to override instance type, volume size, and monitoring

## Usage

```hcl
module "ec2" {
  source = "../../modules/ec2"

  region           = var.region
  environment      = "dev"
  project_name     = "ecommerce"
  instance_name    = "web-server-01"
  instance_type    = "t4g.micro"  # Free tier eligible
  
  # Reference VPC and Security Group from other modules
  subnet_id         = module.vpc.public_subnet_1_id
  security_group_id = module.security_groups.ec2_sg_id
  
  # Cost optimization defaults
  root_volume_size = 8                    # Minimal: 8 GiB
  root_volume_type = "gp3"                # Cost effective
  enable_ebs_optimization = false         # Not needed for micro instances
  monitoring_enabled = false              # Avoid extra charges
  associate_public_ip = true              # For public subnet
  
  tags = {
    CostCenter = "engineering"
  }
}
```

## Cost Optimization Notes

- **Instance Type**: `t4g.micro` includes AWS Graviton processor and is free-tier eligible
  - Alternative: `t3.micro` for x86 architecture
- **Volume**: 8 GiB gp3 is minimal; gp3 replaces older gp2 with better performance per dollar
- **Monitoring**: Disabled by default (detailed CloudWatch costs ~$3.50/instance/month)
- **EBS Optimization**: Disabled (not cost-effective for t-class instances)
- **Encryption**: Not enabled on root volume (free, but marginal performance overhead)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| region | string | - | AWS region |
| environment | string | - | Environment name (dev/stage/prod) |
| project_name | string | - | Project identifier |
| instance_name | string | "web-server" | Instance resource name |
| instance_type | string | "t4g.micro" | EC2 instance type |
| subnet_id | string | - | Subnet to launch instance in |
| security_group_id | string | - | Security group ID |
| root_volume_size | number | 8 | Root volume size in GiB |
| root_volume_type | string | "gp3" | EBS volume type |
| enable_ebs_optimization | bool | false | Enable EBS optimization |
| associate_public_ip | bool | true | Assign public IP |
| monitoring_enabled | bool | false | Enable detailed monitoring |
| tags | map(string) | {} | Additional tags |

## Outputs

- `instance_id` — EC2 instance ID
- `private_ip` — Private IP address
- `public_ip` — Public IP address (if assigned)
- `public_dns` — Public DNS name
- `primary_network_interface_id` — ENI ID
- `security_group_id` — Associated security group
- `instance_state` — Instance state (running/stopped/etc.)

## Requirements

- VPC and subnet already provisioned
- Security group already created with required ingress/egress rules
- IAM permissions to launch EC2 instances and describe AMIs
