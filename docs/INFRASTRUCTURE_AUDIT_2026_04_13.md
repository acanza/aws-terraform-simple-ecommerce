# Infrastructure & Security Audit
**Date**: April 13, 2026  
**Environment**: dev  
**Status**: Requires critical corrections before production

---

## EXECUTIVE SUMMARY

Your Terraform infrastructure is **correctly structured** with module separation, but has **critical security vulnerabilities** and **connectivity issues** that must be corrected.

| Category | Status | Findings |
|----------|--------|----------|
| **Structure** | ✅ Good | Well-organized modules, validated variables |
| **Encryption** | ❌ CRITICAL | EBS without encryption, S3 with base AES256 |
| **Public Access** | ⚠️ HIGH | 3 public CIDRs without restriction, S3 intentionally public |
| **Logging/Audit** | ❌ CRITICAL | No VPC Flow Logs, no CloudWatch RDS logs |
| **Connectivity** | ✅ Correct | VPC + SG rules correctly configured for EC2-RDS |
| **IAM** | ✅ Correct | Least privilege configured, role-specific permission |

---

## 1. CRITICAL VULNERABILITIES (BLOCKING FOR PRODUCTION)

### 1.1 [CRITICAL] EC2: Root Volume Without Encryption

**Location**: [modules/ec2/main.tf](modules/ec2/main.tf#L30)

```hcl
root_block_device {
  volume_type           = var.root_volume_type
  volume_size           = var.root_volume_size
  delete_on_termination = true
  
  encrypted = false  # ❌ VULNERABLE: No encryption
}
```

**Risk**: 
- EBS volume exposed without encryption protection
- Security standards violation (SOC2, ISO 27001)
- Data at rest without protection

**Impact**: OS and application data are encrypted without protection on EBS storage.

**Remediation**: Change to `encrypted = true`

```hcl
encrypted = true
```

---

### 1.2 [CRITICAL] Missing VPC Flow Logs

**Location**: [modules/vpc/main.tf](modules/vpc/main.tf)

**Risk**:
- No network traffic audit
- Cannot investigate connectivity issues
- Compliance violation

**Remediation**: Add VPC Flow Logs to VPC module

```hcl
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}
```

---

### 1.3 [CRITICAL] RDS: Logging Not Enabled (when active)

**Location**: [modules/rds/main.tf](modules/rds/main.tf) - Line ~90

**Risk**:
- SQL queries not audited
- Impossible to investigate unauthorized access
- SOC2/ISO 27001 violation

**Remediation**: Add logs to CloudWatch:

```hcl
enabled_cloudwatch_logs_exports = ["postgresql"]

# And create IAM role for RDS Enhanced Monitoring:
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
```

---

## 2. SECURITY VULNERABILITIES (HIGH RISK)

### 2.1 [HIGH] EC2: Unrestricted Outbound Traffic

**Location**: [modules/security_groups/main.tf](modules/security_groups/main.tf#L58)

```hcl
# Outbound: Allow all traffic (EC2 needs to reach RDS, S3, NAT gateway, etc.)
resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  description       = "Allow all outbound traffic (to RDS, S3, internet, etc.)"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"  # ⚠️ Overly permissive
  security_group_id = aws_security_group.ec2.id
}
```

**Risk**:
- EC2 can connect to any destination without restriction
- Possible undetected data exfiltration
- No control over EC2 service connectivity

**Impact**: If EC2 is compromised, attacker can communicate with external C2C (Command & Control) servers.

**Remediation**: Allow only necessary traffic:

```hcl
# Outbound 1: RDS (port 5432)
resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  description              = "EC2 to RDS PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.ec2.id
}

# Outbound 2: S3 (HTTPS)
resource "aws_vpc_security_group_egress_rule" "ec2_to_s3" {
  description       = "EC2 to S3 via HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id
}

# Outbound 3: DNS (port 53)
resource "aws_vpc_security_group_egress_rule" "ec2_dns" {
  description       = "EC2 DNS resolution"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2.id
}
```

---

### 2.2 [HIGH] HTTP/HTTPS: Accept 0.0.0.0/0 (Correct but requires Validation)

**Location**: [modules/security_groups/main.tf](modules/security_groups/main.tf#L20-L50)

```hcl
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  count       = var.enable_http ? 1 : 0
  description = "HTTP from internet"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"  # ⚠️ Public by design (web server)
  ...
}

resource "aws_vpc_security_group_ingress_rule" "ec2_https" {
  count       = var.enable_https ? 1 : 0
  description = "HTTPS from internet"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"  # ⚠️ Public by design (web server)
  ...
}
```

**Status**: ✅ Correct (Intentional for web server)  
**Validation**: Both disabled by default in `terraform.tfvars` - Good practice

Current config in `terraform.tfvars`:
```
enable_http  = false
enable_https = false
```

---

### 2.3 [HIGH] S3 Frontend: Public Access Block Disabled

**Location**: [modules/s3-frontend/main.tf](modules/s3-frontend/main.tf#L10-L18)

```hcl
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false  # ⚠️ Allows public ACLs
  block_public_policy     = false  # ⚠️ Allows public policies
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

**Status**: ⚠️ By design (static website hosting) - BUT REQUIRES CONTROLS

**Risk Mitigated**: The bucket policy only allows `s3:GetObject` (read):

```hcl
data "aws_iam_policy_document" "frontend_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]  # ✅ Read-only

    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }
}
```

**Validation**: Protections in place:
- ✅ Versioning enabled (`Enabled`)
- ✅ SSE-S3 encryption enabled
- ✅ Policy restricted to `s3:GetObject` (no `PutObject`, `DeleteObject`)
- ✅ CloudFront would restrict direct access in production

**Recommendation**: Document clear intention in code:

```hcl
# ============================================================
# IMPORTANT: This bucket is intentionally public for static
# website hosting. Access is restricted to GET operations only.
# For production, enable CloudFront as content delivery layer.
# ============================================================
```

---

## 3. CONNECTIVITY AND VALIDATION ISSUES

### 3.1 ✅ EC2 ↔ RDS: CONNECTIVITY CORRECT

**Connection Architecture**:

```
EC2 (Public Subnet)
  ↓ (Security Group: ec2)
  ↓ (Port 5432 TCP)
  ↓
RDS (Private Subnets, Multi-AZ)
  ↑ (Security Group: rds)
  ↑ (Ingress from: ec2 SG)
```

**Component Validation**:

| Component | Status | Validation |
|-----------|--------|-----------|
| **VPC CIDR** | ✅ | 10.0.0.0/16 valid, well documented |
| **Public Subnets** | ✅ | 2 subnets in different AZs (10.0.1.0/24, 10.0.2.0/24) |
| **Private Subnets** | ✅ | 2 subnets in different AZs (10.0.10.0/24, 10.0.11.0/24) |
| **Internet Gateway** | ✅ | Assigned to VPC, route in public RT |
| **NAT Gateway** | ⚠️ | **SINGLE AZ**: Single Point of Failure (SPOF) |
| **EC2 → RDS SG Rule** | ✅ | Rule `rds_from_ec2` allows port 5432 from EC2 SG |
| **RDS DB Subnet Group** | ✅ | Defined with private subnets multi-AZ |

**EC2 to RDS Traffic Flow** (Validated):

```
EC2 Instance (subnet-1, sg-ec2)
  ↓ Outbound on EC2 SG: Allow all (includes port 5432)
  ↓ VPC routing: Private Subnet 1 → Local
  ↓ RDS SG: Ingress rule "rds_from_ec2" 
    (From: sg-ec2, Port: 5432, Proto: TCP)
  ↓
RDS Instance (Subnet Group multi-AZ)
  ✅ CONNECTIVITY CORRECT
```

**Credential Validation**:
- ✅ IAM Role EC2 has `secretsmanager:GetSecretValue`
- ✅ KMS condition limited to `secretsmanager.region.amazonaws.com`
- ✅ Password in `terraform.tfvars` (change for production)

---

### 3.2 ✅ EC2 → S3: CONNECTIVITY CORRECT

**SG Rule**: EC2 Outbound allows all (0.0.0.0/0) ✅  
**IAM Policy**: EC2 has basic S3 permissions `modules/iam/main.tf` ✅  
**Access**: S3 VPC Endpoint NOT configured (uses NAT Gateway) ⚠️

**Recommendation**: For better security and lower cost, add S3 VPC Endpoint:

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-endpoint"
    }
  )
}
```

---

### 3.3 ✅ EC2 → Internet (NAT): CONNECTIVITY CORRECT

**Flow**:
```
EC2 (10.0.10.x) 
  ↓ Route in Private Subnet → NAT Gateway
  ↓ NAT Gateway (10.0.1.0/24) 
  ↓ IGW → Internet
```

**Validation**: ✅ Correct  
**Risk**: ⚠️ **Single NAT Gateway** = SPOF (single point of failure)

---

## 4. LOGGING AND AUDIT DEFICIENCIES

### 4.1 [CRITICAL] No VPC Flow Logs

**Status**: ❌ Not configured

**Impact**: 
- Cannot investigate network traffic rejections
- Impossible to detect malicious patterns
- Hard to diagnose connectivity issues

**Remediation**: See section 1.2 above

---

### 4.2 [CRITICAL] No CloudWatch Logs on RDS (when enabled)

**Status**: ❌ Not configured

**Impact**:
- SQL queries not logged
- Unauthorized access not detected
- Incomplete audit trail

**Remediation**: See section 1.3 above

---

### 4.3 [MEDIUM] No S3 Access Logging

**Location**: [modules/s3/main.tf](modules/s3/main.tf) and [modules/s3-frontend/main.tf](modules/s3-frontend/main.tf)

**Recommendation**: Add logging:

```hcl
resource "aws_s3_bucket_logging" "images" {
  bucket = aws_s3_bucket.images.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "images-logs/"
}

# Create separate logs bucket (no public access)
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-logs"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

---

## 5. INFRASTRUCTURE ISSUES

### 5.1 [ACCEPTABLE for DEV, CRITICAL for PROD/STAGE] Single NAT Gateway = SPOF

**Location**: [modules/vpc/main.tf](modules/vpc/main.tf)

**Problem**: Only 1 NAT Gateway in AZ-1

**Cost Analysis**:
- Single NAT: ~$0.045/hour = **$32.85/month per NAT**
- Multi-NAT HA: 2 NATs = **+$65.70/month additional cost**
- Annual cost of HA: **~$788 extra**

**Environment-Specific Assessment**:

| Environment | Single NAT | Decision | Reasoning |
|-------------|-----------|----------|-----------|
| **DEV** | ✅ ACCEPTABLE | Keep Single NAT | Non-critical, tolerable downtime < 5 min |
| **STAGE** | ⚠️ RECOMMENDED | Add Multi-NAT | Pre-production validation, near-prod requirements |
| **PROD** | ❌ NOT ACCEPTABLE | MANDATORY Multi-NAT | Production users require 99.95% SLA, HA mandatory |

**Risk for DEV** (Current Single NAT):
- If AZ-1 goes down: Private Subnets lose internet access for 2-5 minutes (AWS auto-recovery)
- RDS cannot reach Secrets Manager during outage (but RDS itself is multi-AZ, independent)
- Acceptable in development environment

**Best Practice Alternative for DEV** (Cost-Optimized HA):
Instead of paying for Multi-NAT, consider:

```hcl
# Option 1: VPC Endpoints (FREE/minimal cost, improves security)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-secrets-endpoint"
    }
  )
}
```

Benefits:
- ✅ Reduces NAT dependency for S3 and Secrets Manager
- ✅ Improves security (traffic stays within AWS network)
- ✅ Cost: Minimal (VPC endpoints are free for gateway type, ~$7/month for interface)
- ✅ Better SLA than NAT Gateway

**Remediation Path**:

1. **DEV (Current)**: Keep Single NAT + Add VPC Endpoints
   - Improves security
   - Reduces NAT risk
   - Minimal cost increase

2. **STAGE/PROD**: Add Multi-NAT Gateway

```hcl
# Second NAT Gateway for Production HA
resource "aws_eip" "nat_2" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-2"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-2"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Route in Private Subnet 2
resource "aws_route" "private_2_nat" {
  route_table_id         = aws_route_table.private_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_2.id
}
```

**Recommendation Summary**:
- ✅ **DEV**: Keep Single NAT (acceptable), add VPC Endpoints for better security & resilience
- ⚠️ **STAGE**: Plan Multi-NAT implementation before production deployment
- ❌ **PROD**: Multi-NAT Gateway mandatory for HA and compliance

---

### 5.2 [MEDIUM] EC2 Monitoring Disabled

**Location**: [envs/dev/main.tf](envs/dev/main.tf#L40)

```hcl
monitoring_enabled = false
```

**Recommendation**: Enable for production:

```hcl
monitoring_enabled = true  # CloudWatch detailed monitoring
```

---

### 5.3 [MEDIUM] EBS Optimization Disabled

**Location**: [envs/dev/main.tf](envs/dev/main.tf#L38)

```hcl
enable_ebs_optimization = false
```

**Status**: Acceptable for t4g.micro (free tier), but enable in production

---

## 6. VARIABLES AND VERSIONS VALIDATION

### 6.1 ✅ Version Pinning Configured

**Location**: [modules/*/terraform.tf](modules/)

```hcl
terraform {
  required_version = ">= 1.5, < 2.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Status**: ✅ Correct

---

### 6.2 ✅ Variable Validation Configured

**Location**: [modules/vpc/variables.tf](modules/vpc/variables.tf#L5)

```hcl
variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}
```

**Status**: ✅ Correct

---

## 7. PRIORITIZED REMEDIATION PLAN

### P0 - CRITICAL (Before any application)

- [ ] **EC2 EBS Encryption**: Change `encrypted = false` to `true`
- [ ] **VPC Flow Logs**: Implement CloudWatch Logs for network audit
- [ ] **RDS CloudWatch Logs**: Enable `enabled_cloudwatch_logs_exports = ["postgresql"]`

### P1 - HIGH (Before production)

- [ ] **EC2 Egress Restrictions**: Limit outbound traffic to RDS, S3, DNS only
- [ ] **S3 Access Logging**: Implement logging on S3 buckets
- [ ] **Enhanced Monitoring RDS**: Add IAM role for RDS monitoring
- [ ] **VPC Endpoints**: Add S3 and Secrets Manager endpoints (DEV: improves resilience, STAGE/PROD: enable Multi-NAT)
- [ ] **Multi-NAT Gateway**: Add NAT in AZ-2 for HA (STAGE/PROD only, optional for DEV)

### P2 - MEDIUM (Security improvements)

- [ ] **EC2 Monitoring**: Enable CloudWatch detailed monitoring for production
- [ ] **CloudTrail**: API audit at AWS account level
- [ ] **AWS Config**: Automatic compliance monitoring
- [ ] **Documentation**: Update README with security diagram

### P3 - LOW (Optimization)

- [ ] **Consolidated Logging**: Centralize all logs in CloudWatch
- [ ] **Secrets Rotation**: Implement Lambda for RDS password rotation
- [ ] **Backup Strategy**: Implement RDS automated backups and snapshots
- [ ] **Cost Optimization**: Evaluate Reserved Instances if in production

---

## 8. CURRENT ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│ VPC (10.0.0.0/16)                                                │
│                                                                   │
│ ┌──────────────────┐  ┌──────────────────┐                       │
│ │ PUBLIC SUBNET 1  │  │ PUBLIC SUBNET 2  │                       │
│ │ (10.0.1.0/24)    │  │ (10.0.2.0/24)    │                       │
│ │                  │  │                  │                       │
│ │ ┌──────────────┐ │  │ ┌──────────────┐ │                       │
│ │ │ EC2 Instance │ │  │ │ NAT Gateway  │─┼─── Internet Gateway   │
│ │ │ (Public IP)  │ │  │ │ (Single AZ!) │ │           ↕           │
│ │ │ sg-ec2       │ │  │ │              │ │        Internet        │
│ │ └──────────────┘ │  │ └──────────────┘ │                       │
│ └──────────────────┘  └──────────────────┘                       │
│          ↓ Egress (Allow All)                                    │
│                                                                   │
│ ┌──────────────────┐  ┌──────────────────┐                       │
│ │ PRIVATE SUBNET 1 │  │ PRIVATE SUBNET 2 │                       │
│ │ (10.0.10.0/24)   │  │ (10.0.11.0/24)   │                       │
│ │                  │  │                  │                       │
│ │ ┌──────────────┐ │  │ ┌──────────────┐ │                       │
│ │ │  RDS Replica │ │  │ │  RDS Primary │ │                       │
│ │ │  (Standby)   │ │  │ │  (Active)    │ │                       │
│ │ │ sg-rds       │─┼──┼─│ sg-rds       │ │                       │
│ │ │ Port 5432    │ │  │ │ Port 5432    │ │                       │
│ │ └──────────────┘ │  │ └──────────────┘ │                       │
│ └──────────────────┘  └──────────────────┘                       │
│          ↓ Route via NAT Gateway                                 │
│                                                                   │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ S3 Buckets (Global)                                         │ │
│ │ • images (Private, ECS/App uploads)     ✅ Encrypted        │ │
│ │ • frontend (Public static website)      ✅ Encrypted        │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

SECURITY FLOWS:
✅ EC2 → RDS: Port 5432, restrictive SG rule
⚠️ EC2 → Internet: ALL outbound (SPOF + over-permissive)
✅ EC2 → S3: Via NAT Gateway → Internet (consider VPC Endpoint)
❌ VPC internal: NO flow logs
```

---

## 9. POST-REMEDIATION VALIDATION CHECKLIST

After implementing corrections:

```bash
# 1. Terraform validation
terraform validate

# 2. Automatic formatting
terraform fmt -recursive

# 3. Plan without destructive changes
terraform plan -out=tfplan
# Verify: nothing with "(forces new resource)"

# 4. Validate security groups
aws ec2 describe-security-groups --region eu-west-3 \
  --filters "Name=vpc-id,Values=vpc-xxx" \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions,IpPermissionsEgress]'

# 5. Validate RDS logs if enabled
aws rds describe-db-instances --region eu-west-3 \
  --query 'DBInstances[0].EnabledCloudwatchLogsExports'

# 6. Check VPC Flow Logs
aws ec2 describe-flow-logs --region eu-west-3 \
  --filter "Name=resource-id,Values=vpc-xxx"
```

---

## 10. CONCLUSIONS AND RECOMMENDATIONS

### ✅ CORRECT ASPECTS

1. **Modular Architecture**: Correct separation of concerns
2. **Variable Validation**: Constraints on environment, CIDR, etc.
3. **IAM Least Privilege**: Roles correctly restricted (EC2, Terraform user)
4. **Multi-AZ**: Subnets distributed across different AZs for HA
5. **SG Rules**: SG rules correctly configured for EC2-RDS flow
6. **Encryption at Rest**: S3 with SSE-S3, EBS with AES256 (though by default)
7. **Version Pinning**: Terraform and AWS provider with fixed versions

### ❌ CRITICAL TO FIX

1. **EBS Encryption**: Enable encryption on EC2 root volume
2. **VPC Flow Logs**: Implement for network audit
3. **RDS Logging**: Enable CloudWatch logs when RDS is active

### ⚠️ IMPORTANT IMPROVEMENTS

1. **Fix Egress**: Limit EC2 outbound to only necessary services
2. **VPC Endpoints**: Add for S3 and Secrets Manager (improves resilience, reduces NAT dependency)
3. **S3 Access Logs**: Implement logging on buckets
4. **CloudTrail**: API audit at account level
5. **Single NAT Gateway** (Environment-dependent):
   - DEV: ✅ Acceptable (add VPC Endpoints for cost-effective resilience)
   - STAGE: ⚠️ Plan Multi-NAT before production
   - PROD: ❌ Mandatory Multi-NAT for HA and compliance

---

## NEXT STEPS

1. **Immediate (DEV)**: Implement P0 corrections (EBS encryption, Flow Logs, RDS logging)
2. **This week (DEV)**: Add VPC Endpoints for cost-effective resilience improvement
3. **Before STAGE**: Apply P1 changes + evaluate Multi-NAT cost vs. requirements
4. **Before PROD**: Mandatory Multi-NAT implementation for HA + complete P2

---

**Audit performed by**: GitHub Copilot - Terraform IaC Agent  
**Methodology**: AWS Well-Architected Framework (Security Pillar)  
**Reference**: AWS IAM Review Skill + Pre-Plan Validation  
**Updated**: April 13, 2026 - Environment-specific NAT Gateway guidance added
