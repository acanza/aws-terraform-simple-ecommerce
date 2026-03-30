# VPC Module

This module creates a production-ready VPC with public and private subnets across multiple availability zones.

## Architecture

- **1 VPC** with configurable CIDR block (default: `10.0.0.0/16`)
- **2 Public Subnets** with automatic public IP assignment (one per AZ)
- **2 Private Subnets** with outbound internet access via NAT Gateway (one per AZ)
- **Internet Gateway** for public subnet internet access
- **NAT Gateway** for private subnet outbound internet access
- **Elastic IP** for NAT Gateway
- **Route Tables** for public and private traffic routing

## Network Design

| Component | CIDR | AZ | Purpose |
|-----------|------|----|---------| 
| Public Subnet 1 | 10.0.1.0/24 | us-east-1a | Web-facing resources |
| Public Subnet 2 | 10.0.2.0/24 | us-east-1b | Web-facing resources (HA) |
| Private Subnet 1 | 10.0.11.0/24 | us-east-1a | Application tier |
| Private Subnet 2 | 10.0.12.0/24 | us-east-1b | Application tier (HA) |

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  region       = "us-east-1"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "ecommerce"

  tags = {
    CostCenter = "engineering"
  }
}
```

## Input Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `region` | AWS region for deployment | `string` | `us-east-1` |
| `environment` | Environment name (dev/stage/prod) | `string` | - |
| `vpc_cidr` | CIDR block for the VPC | `string` | `10.0.0.0/16` |
| `project_name` | Project name for naming convention | `string` | `ecommerce` |
| `tags` | Additional tags for all resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC |
| `vpc_cidr` | CIDR block of the VPC |
| `public_subnet_1_id` | ID of public subnet in AZ 1 |
| `public_subnet_2_id` | ID of public subnet in AZ 2 |
| `private_subnet_1_id` | ID of private subnet in AZ 1 |
| `private_subnet_2_id` | ID of private subnet in AZ 2 |
| `public_subnets` | List of all public subnet IDs |
| `private_subnets` | List of all private subnet IDs |
| `nat_gateway_ip` | Public IP of NAT Gateway |
| `internet_gateway_id` | ID of Internet Gateway |
| `nat_gateway_id` | ID of NAT Gateway |

## High Availability

- Resources distributed across 2 availability zones
- Single NAT Gateway in public subnet 1 (cost optimization for dev/stage)
- Both private subnets route through same NAT Gateway (scale to multi-NAT in production)

## Security Features

- Public subnets explicitly marked for internet-facing resources
- Private subnets isolated with no direct internet access
- Outbound traffic from private subnets controlled via NAT Gateway
- All resources tagged for auditing and cost allocation
