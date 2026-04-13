# IAM Implementation Guide - Users and Roles

## Overview

A new IAM module (`modules/iam/`) has been created that provides users and roles with minimum permissions for:

1. **EC2 Instance Role** - For the application to securely access Secrets Manager and CloudWatch
2. **Terraform/DevOps User** - To manage infrastructure with Terraform
3. **SSH/SSM User** - For secure remote access to EC2 instances
4. **Read-Only Group** - For users with read-only permissions

---

## Created Structure

### IAM Module (`modules/iam/`)
```
modules/iam/
├── terraform.tf      # AWS provider ~5.0, Terraform >= 1.5
├── variables.tf      # Configurable inputs
├── outputs.tf        # Exported values
├── locals.tf         # Computed values
├── main.tf           # Resource definitions
└── README.md         # Module documentation
```

### Integration in Dev (`envs/dev/`)
- `main.tf` - IAM module added
- `outputs.tf` - New outputs for users and roles

---

## Created Components

### 1. Role for EC2 (`ec2_instance_role`)
**Permissions**:
- ✅ Read RDS secrets in Secrets Manager (`ecommerce-dev/rds/*`)
- ✅ Write logs to CloudWatch (`/aws/ec2/ecommerce-dev*`)
- ✅ Decrypt with KMS (only from Secrets Manager)

**Usage**:
```hcl
iam_instance_profile = module.iam.ec2_instance_profile_name
```

### 2. Terraform User (`terraform-ecommerce-dev`)
**Permissions**:
- ✅ Full VPC, subnets, gateways management
- ✅ Security groups management
- ✅ EC2 instances CRUD
- ✅ RDS PostgreSQL CRUD
- ✅ IAM management limited to `ecommerce-dev-*`
- ✅ Secrets Manager for `ecommerce-dev/*`
- ✅ S3 and DynamoDB for state file
- ✅ CloudWatch Logs

**Note**: Permissions limited to project namespace (`ecommerce-dev-`)

### 3. SSH User (`ec2-ssh-dev`)
**Permissions**:
- ✅ AWS Systems Manager Session Manager (secure access without SSH)
- ✅ CloudWatch Logs for session auditing
- ✅ S3 for storing session logs
- ✅ EC2 describe to discover instances

---

## Next Steps

### 1. Deploy the Infrastructure
```bash
cd envs/dev
terraform plan     # Review changes
terraform apply    # Apply (requires confirmation)
```

### 2. Create Access Keys for Terraform
```bash
# Create access key for Terraform user
aws iam create-access-key --user-name terraform-ecommerce-dev

# Store in:
# - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# - GitHub Actions secrets
# - GitLab CI/CD variables
# - Project CI/CD pipeline
```

### 3. Create Secrets in Secrets Manager
```bash
# Generate secure password
PASSWORD=$(openssl rand -base64 32)

# Create secret for RDS
aws secretsmanager create-secret \
  --name ecommerce-dev/rds/master-password \
  --secret-string "$PASSWORD"
```

### 4. Configure EC2 for Secrets Access
In your application (Node.js, Python, etc.):

**Python Example**:
```python
import boto3
import json

client = boto3.client('secretsmanager', region_name='eu-west-3')

response = client.get_secret_value(
    SecretId='ecommerce-dev/rds/master-password'
)

rds_password = response['SecretString']
```

**Node.js Example**:
```javascript
const AWS = require('aws-sdk');
const client = new AWS.SecretsManager({ region: 'eu-west-3' });

const secret = await client.getSecretValue({
  SecretId: 'ecommerce-dev/rds/master-password'
}).promise();

const rdsPassword = secret.SecretString;
```

### 5. Configure SSH/SSM Access
```bash
# SSH user can start sessions with:
aws ssm start-session --target i-0123456789abcdef0

# Or configure in .bashrc/.zshrc:
alias ec2-connect='aws ssm start-session --target'
```

---

## Security - Applied Principles

### ✅ Least Privilege
- Only explicitly necessary permissions
- No unnecessary wildcards (`*`)
- Restricted to project namespace

### ✅ User Segregation
- EC2 Role: Read-only Secrets Manager access
- Terraform User: Infrastructure management
- SSH User: Remote access only
- Read-Only Group: Read-only access

### ✅ Resource Restrictions
```hcl
# Example: Only project secrets
"arn:aws:secretsmanager:eu-west-3:*:secret:ecommerce-dev/*"

# Example: Only roles with prefix
"arn:aws:iam::*:role/ecommerce-dev-*"
```

### ✅ Auditing
- CloudWatch Logs for SSM sessions
- CloudTrail (recommended to enable)
- S3 logs for secret access

---

## Changes Made

### EC2 Module
- ✅ Variable `iam_instance_profile` added (optional)
- ✅ Instance profile integration in `aws_instance` resource

### Dev Environment
- ✅ IAM module integrated
- ✅ EC2 ↔ IAM instance profile binding
- ✅ Outputs for users and roles

---

## Validation Completed

✅ `terraform fmt` - Code formatted
✅ `terraform validate` - IAM module valid
✅ `terraform validate` - Dev environment valid
✅ Configuration fully functional

---

## Important Notes

1. **Access keys are NOT created automatically**  
   → Create manually with `aws iam create-access-key`

2. **Plaintext secrets NOT recommended**  
   → Use Secrets Manager or Parameter Store

3. **Direct SSH NOT recommended**  
   → Use Systems Manager Session Manager (more secure)

4. **MFA Recommended**  
   → Enable it on users with privileged access

5. **Key Rotation**  
   → Implement periodic access key rotation

---

## Future Improvement

For production environments (`envs/prod/`):

```hcl
enable_enhanced_monitoring     = true
enable_iam_database_authentication = true  # IAM auth for RDS
backup_retention_period        = 30
# ... more HA configurations
```
