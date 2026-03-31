# Security Groups Module

This module creates security groups for the ecommerce architecture with minimal, explicit rules.

## Architecture & Rules

### EC2 Security Group (Web Tier - Public Subnets)

**Inbound Rules:**
- **SSH (port 22)**: Restricted to `trusted_ssh_cidr` (variable - e.g., your office IP/32 or corporate VPN)
- **HTTP (port 80)**: Optional (controlled by `enable_http` variable)
- **HTTPS (port 443)**: Optional (controlled by `enable_https` variable)

**Outbound Rules:**
- **All traffic (0.0.0.0/0)**: Allows EC2 to reach RDS, S3, NAT Gateway, and internet

---

### RDS Security Group (Database - Private Subnets)

**Inbound Rules:**
- **Database Port** (default 3306 for MySQL, configurable): Only from EC2 security group

**Outbound Rules:**
- None (deny-by-default for databases)

---

## Design Principles

1. **Least Privilege**: Only required ports and sources are allowed
2. **Explicit Rules**: Using separate `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources (not inline blocks) for clarity and maintainability
3. **Security Group Reference**: RDS rules reference EC2 SG directly, enabling fine-grained access control
4. **No HTTP/HTTPS by Default**: Web traffic disabled unless explicitly enabled (safer defaults for dev)
5. **Parameterized SSH Access**: Trusted IP must be provided by operator (no hardcoded defaults)

---

## Usage

```hcl
module "security_groups" {
  source = "../../modules/security_groups"

  region            = "eu-west-3"
  environment       = "dev"
  project_name      = "ecommerce"
  vpc_id            = module.vpc.vpc_id
  
  # REQUIRED: Replace with your public IP or VPN subnet
  trusted_ssh_cidr  = "203.0.113.0/32"  # Your office IP from ifconfig/myip.com
  
  # Optional: Enable web traffic (disabled by default)
  enable_http       = false
  enable_https      = false
  
  # Optional: For non-MySQL databases
  db_port           = 5432  # PostgreSQL
  # db_port           = 3306  # MySQL (default)
  # db_port           = 1433  # SQL Server
  
  tags = {
    CostCenter = "engineering"
  }
}
```

---

## Input Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `eu-west-3` | AWS region |
| `environment` | string | - | Environment (dev/stage/prod) |
| `project_name` | string | `ecommerce` | Project name for naming |
| `vpc_id` | string | - | VPC ID (required) |
| `trusted_ssh_cidr` | string | - | CIDR for SSH access (required, e.g., `203.0.113.0/32`) |
| `enable_http` | bool | `false` | Enable HTTP to EC2 |
| `enable_https` | bool | `false` | Enable HTTPS to EC2 |
| `db_port` | number | `3306` | Database port (MySQL default) |
| `tags` | map(string) | `{}` | Additional tags |

---

## Outputs

| Name | Description |
|------|-------------|
| `ec2_security_group_id` | ID of EC2 security group |
| `ec2_security_group_arn` | ARN of EC2 security group |
| `rds_security_group_id` | ID of RDS security group |
| `rds_security_group_arn` | ARN of RDS security group |
| `security_groups` | Map of SG IDs (ec2, rds) |

---

## Security Assumptions & Notes

### ✅ What's Secure by Default

- **RDS is NOT publicly accessible**: Only accessible from EC2 security group
- **SSH restricted**: Must provide trusted CIDR (no 0.0.0.0/0 defaults)
- **HTTP/HTTPS disabled**: Must explicitly enable for web services
- **S3/CloudFront**: No security groups needed (handled separately)
- **IAM**: Not part of this module (see iam module)

### ⚠️ Trade-offs & Assumptions

1. **Single EC2 Instance** (simple design)
   - Assumes 1 EC2 in public subnet
   - For auto-scaling: Consider adding ALB/NLB security group and updating rules

2. **All EC2 instances share one SG**
   - Simpler management for dev/stage
   - For prod: Consider layered SGs (web, app, Worker)

3. **RDS port parametrized** (defaults to MySQL 3306)
   - Adjust `db_port` for PostgreSQL (5432), SQL Server (1433), etc.
   - For multiple RDS instances: Would need RDS-specific rules

4. **S3 & CloudFront not included** (by design)
   - S3 uses bucket policies (no SG)
   - CloudFront uses origins (no SG)
   - EC2 will need IAM role with S3 permissions

5. **EC2 egress = all traffic (0.0.0.0/0)**
   - Necessary for reaching: RDS (private subnet), S3, internet via NAT
   - For prod: Could tighten to specific RDS subnet CIDR + S3 VPC Endpoint
   - Current: Acceptable for dev/stage

### 🔴 Known Overly-Permissive Access

**None identified if properly configured:**
- EC2 SSH: Restricted to `trusted_ssh_cidr` (user-defined)
- EC2 HTTP/HTTPS: Disabled by default (opt-in)
- RDS: Only from EC2 SG (no public internet)
- Egress: Necessary for architecture (can't tighten further without additional infrastructure)

**Future improvements** (post-dev):
- Add ALB security group and restrict RDS to ALB->EC2 path
- Replace egress all-traffic with specific endpoint routes for S3, DynamoDB
- Add VPC Flow Logs to monitor actual traffic patterns

---

## Example: Integration with VPC + Dev Environment

```hcl
# envs/dev/main.tf
module "vpc" {
  source = "../../modules/vpc"
  region = "eu-west-3"
  environment = "dev"
}

module "security_groups" {
  source = "../../modules/security_groups"
  vpc_id = module.vpc.vpc_id
  trusted_ssh_cidr = "203.0.113.0/32"  # Replace with your IP
  environment = "dev"
}

# Output for reference
output "ec2_sg" {
  value = module.security_groups.ec2_security_group_id
}
```

Launch EC2 with: `security_groups = [module.security_groups.ec2_security_group_id]`  
Launch RDS with: `vpc_security_group_ids = [module.security_groups.rds_security_group_id]`
