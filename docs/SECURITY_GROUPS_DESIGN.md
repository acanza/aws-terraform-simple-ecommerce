# Security Groups Design - Assumptions & Risk Assessment

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet / CloudFront                  │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────▼─────────┐
        │   Internet GW    │
        └────────┬────────┘
                 │
    ┌────────────▼──────────────┐
    │    Public Subnets         │
    │  (eu-west-3a, eu-west-3b) │
    │                           │
    │  EC2 (Web Server)         │
    │  SG: ec2-sg               │
    │  Rules:                   │
    │  - SSH from trusted_ip    │
    │  - HTTP/HTTPS (optional)  │
    └────────────┬──────────────┘
                 │
    ┌────────────▼──────────────┐
    │    Private Subnets        │
    │  (eu-west-3a, eu-west-3b) │
    │                           │
    │  RDS (Database)           │
    │  SG: rds-sg               │
    │  Rules:                   │
    │  - DB Port from EC2 SG    │
    └───────────────────────────┘
                 │
        ┌────────▼─────────┐
        │   NAT Gateway    │
        └──────────────────┘
```

---

## 📋 Design Assumptions

### 1. **Architecture Type: Single Web Tier + Database**
   - **Assumption**: 1 EC2 instance in public subnets (web server)
   - **Assumption**: 1 RDS instance in private subnets (database)
   - **Impact**: Simple security group design with 2 SGs
   - **Future**: Multi-tier design (ALB + ASG) would require additional SGs

### 2. **EC2 web traffic: HTTP/HTTPS (Disabled by Default)**
   - **Assumption**: Web traffic is optional, must be explicitly enabled
   - **Why**: Safer defaults; operator must intentionally allow internet access
   - **Configuration**: `enable_http = false` and `enable_https = false` by default
   - **Flexibility**: Can enable via variables in terraform.tfvars

### 3. **SSH Access: Restricted to Trusted CIDR**
   - **Assumption**: SSH is restricted to a specific CIDR (no 0.0.0.0/0 access)
   - **Why**: SSH port (22) is a common attack target; must be restricted
   - **Implementation**: Variable `trusted_ssh_cidr` is REQUIRED (no default)
   - **Example**: `trusted_ssh_cidr = "203.0.113.0/32"` (your office IP)
   - **For VPN**: `trusted_ssh_cidr = "203.0.113.0/24"` (corporate VPN subnet)

### 4. **RDS Access: Exclusive to EC2 Security Group**
   - **Assumption**: Database is only accessible from web servers
   - **How**: RDS SG has inbound rule from EC2 SG (security group reference)
   - **Why**: Prevents unauthorized direct database access from internet or other sources
   - **Limitation**: Single database port (configurable, default 3306 for MySQL)

### 5. **Database Port: Parameterized (Default MySQL)**
   - **Assumption**: Database port is 3306 (MySQL default)
   - **Flexibility**: Configurable for PostgreSQL (5432), SQL Server (1433), etc.
   - **Implementation**: Variable `db_port` allows override
   - **Limitation**: Cannot have multiple RDS instances on different ports (would need per-RDS SGs)

### 6. **EC2 Outbound: All Traffic (0.0.0.0/0)**
   - **Assumption**: EC2 needs broad outbound access
   - **Why**: Required for:
     - Reaching RDS in private subnets
     - S3 access (or via VPC Endpoint in future)
     - Internet access via NAT Gateway
     - Package manager updates
   - **Trade-off**: Permissive outbound; can be tightened with VPC Endpoints post-dev

### 7. **RDS Outbound: No Rules (Deny-by-Default)**
   - **Assumption**: Database doesn't need outbound internet access
   - **Why**: Databases are inbound-only by design
   - **Future**: If RDS needs to reach external APIs, add explicit rules

### 8. **S3 & CloudFront: Not Included**
   - **Assumption**: S3 doesn't use security groups (uses bucket policies)
   - **Assumption**: CloudFront uses origin access identity (not SGs)
   - **Impact**: EC2 will need IAM role + S3 permissions (separate module)

### 9. **Simple Separate Rules (Not Inline)**
   - **Assumption**: Using `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` (not inline blocks)
   - **Why**: Better readability, easier to add/remove individual rules, version control friendly
   - **Trade-off**: Slightly more lines of code but more maintainable

### 10. **Single Environment: Dev Only**
   - **Assumption**: This design is for dev/stage environments
   - **For Production**: Would add stricter ingress controls, VPC Endpoints, ALB, etc.

---

## ⚠️ Risk Assessment

### 🔴 CRITICAL RISKS

**1. Missing `trusted_ssh_cidr` variable → SSH exposed to 0.0.0.0/0**
   - **Risk**: If operator doesn't provide `trusted_ssh_cidr`, Terraform will fail (GOOD)
   - **Severity**: CRITICAL if someone manually adds SSH rule with 0.0.0.0/0
   - **Mitigation**: Variable is required (no default); validation checks CIDR syntax
   - **Status**: ✅ Protected

**2. HTTP/HTTPS enabled (0.0.0.0/0) without authentication**
   - **Risk**: If `enable_http = true` or `enable_https = true`, web server is public
   - **Severity**: CRITICAL if web server has vulnerable applications
   - **Assumption**: Web server runs hardened application (authentication, WAF)
   - **Mitigation**: Disabled by default; operator must explicitly enable
   - **Status**: ⚠️ Operator responsibility

### 🟠 HIGH RISKS

**1. EC2 → Internet (0.0.0.0/0) outbound access**
   - **Risk**: EC2 can reach any external IP; could be used for data exfiltration
   - **Severity**: HIGH for prod; ACCEPTABLE for dev
   - **Mitigation**: 
     - For dev/stage: Current design is acceptable
     - For prod: Tighten to S3 VPC Endpoint + RDS subnet CIDR only
   - **Status**: ⚠️ Known trade-off for dev

**2. Single RDS instance accessible from all EC2s**
   - **Risk**: Compromised EC2 = compromised database
   - **Severity**: HIGH (typical for architecture)
   - **Mitigation**: 
     - Proper OS hardening on EC2
     - Strong RDS master password (Secrets Manager)
     - RDS read replicas for backups
   - **Status**: ⚠️ Architectural limitation (not a SG issue)

**3. No network encryption (RDS in private subnet)**
   - **Risk**: RDS traffic travels unencrypted to EC2
   - **Severity**: MEDIUM (mitigated by private subnet, encryption at rest)
   - **Mitigation**: RDS SSL/TLS should be enforced at application layer
   - **Status**: ⚠️ Requires RDS configuration (not SG)

### 🟡 MEDIUM RISKS

**1. DB port exposed to EC2 → all EC2 applications**
   - **Risk**: All applications on EC2 can access database (no app-level isolation)
   - **Severity**: MEDIUM (assumes single app per EC2)
   - **Assumption**: One application per EC2; if multiple apps, need connection pooling/proxy
   - **Status**: ⚠️ Acceptable for dev

**2. HTTP (port 80) enabled → plaintext traffic**
   - **Risk**: Credentials/data transmitted unencrypted
   - **Severity**: MEDIUM (mitigated by HTTPS)
   - **Mitigation**: Always use HTTPS; redirect HTTP → HTTPS at application layer
   - **Status**: ⚠️ App responsibility (not SG)

**3. No VPC Flow Logs**
   - **Risk**: Cannot audit actual traffic, debugging network issues
   - **Severity**: MEDIUM (operational, not security)
   - **Mitigation**: Add VPC Flow Logs to CloudWatch in next iteration
   - **Status**: ⏳ Future improvement

### 🟢 LOW RISKS

**1. NAT Gateway IP exposure**
   - **Risk**: Outbound traffic uses single NAT Gateway IP (predictable)
   - **Severity**: LOW
   - **Mitigation**: Single NAT acceptable for dev; prod uses multi-NAT HA
   - **Status**: ✅ Acceptable for dev

**2. No SSH key rotation policy**
   - **Risk**: Long-lived SSH keys (EC2 Key Pairs)
   - **Severity**: LOW (depends on key management)
   - **Mitigation**: Implement key rotation policy, SSM Session Manager in future
   - **Status**: ⏳ Future improvement

---

## 🔐 Overly Permissive Access Assessment

### Current Configuration (if properly used)

✅ **NOT overly permissive** if configured correctly:
- ✅ SSH: Limited to `trusted_ssh_cidr` (not 0.0.0.0/0)
- ✅ HTTP/HTTPS: Disabled by default (opt-in only)
- ✅ RDS: Only from EC2 SG (not public internet)
- ✅ Outbound: Necessary for architecture

### Potential Issues (if misconfigured)

❌ **Would be overly permissive if:**
1. SSH rule added with `cidr_ipv4 = "0.0.0.0/0"` (manual override)
2. `enable_http = true` on untested/vulnerable app
3. `enable_https = true` without HTTPS/TLS enforced
4. RDS port opened to 0.0.0.0/0 (manual error)

### Mitigation

- ✅ Variables validated (CIDR syntax, boolean flags)
- ✅ Separate rule resources (prevent accidental inline modifications)
- ⚠️ Manual override still possible (operator responsibility)
- ⏳ Future: Add AWS Security Hub, Config rules for drift detection

---

## 📊 Implementation Checklist

### Before `terraform plan`:

- [ ] Determine your trusted SSH IP
  ```bash
  # Find your public IP
  curl https://ifconfig.me
  # Example: 203.0.113.42 → provide as 203.0.113.42/32
  ```

- [ ] Decide: Enable HTTP or HTTPS?
  - [ ] No (default, safest) → leave `enable_http = false`, `enable_https = false`
  - [ ] Yes, HTTP only → set `enable_http = true`
  - [ ] Yes, HTTPS (recommended) → set `enable_https = true` + enable_http = true (redirect)

- [ ] Check database type and port
  - [ ] MySQL (default: 3306) → leave as default
  - [ ] PostgreSQL (5432) → set `db_port = 5432`
  - [ ] SQL Server (1433) → set `db_port = 1433`

### terraform.tfvars (dev) example:

```hcl
region            = "eu-west-3"
vpc_cidr          = "10.0.0.0/16"
trusted_ssh_cidr  = "203.0.113.0/32"  # ← MUST PROVIDE
enable_http       = false
enable_https      = false
db_port           = 3306
```

### Expected Terraform output:

```
Plan: 14 to add, 0 to change, 0 to destroy

+ aws_security_group.ec2
+ aws_security_group.rds
+ aws_vpc_security_group_ingress_rule.ec2_ssh
+ aws_vpc_security_group_ingress_rule.ec2_http (if enabled)
+ aws_vpc_security_group_ingress_rule.ec2_https (if enabled)
+ aws_vpc_security_group_egress_rule.ec2_all_outbound
+ aws_vpc_security_group_ingress_rule.rds_from_ec2
+ ... (8 total resources)
```

---

## 🎯 Summary

| Aspect | Status | Rationale |
|--------|--------|-----------|
| **SSH Restricted** | ✅ SECURE | Requires trusted CIDR, no 0.0.0.0/0 default |
| **Web Traffic** | ✅ SECURE | Disabled by default, must enable explicitly |
| **RDS Isolated** | ✅ SECURE | Only accessible from EC2 SG |
| **Outbound Access** | ⚠️ ACCEPTABLE | Necessary for dev/stage; tighten for prod |
| **Architecture** | ✅ SIMPLE | 2 SGs, 7 rules total, easy to understand |
| **Maintainability** | ✅ GOOD | Separate rule resources, parametrized |
| **S3/CloudFront** | ✅ NOT INCLUDED | As specified, handled separately |

---

## 🔄 Next Steps (Out of Scope)

1. **EC2 Module** — Launch instances with these security groups
2. **RDS Module** — Create database with this security group
3. **IAM Module** — EC2 role for S3 access, EC2 role for SSM
4. **VPC Endpoints** — S3/DynamoDB endpoints to tighten outbound
5. **ALB** — Add load balancer, separate web/app SGs
6. **VPC Flow Logs** — Monitor actual traffic patterns
7. **Security Groups Tagging** — Improve cost allocation and automation

---

**Module Created**: Security Groups v1.0  
**Date**: March 31, 2026  
**Reversibility**: 100% (code not applied)
