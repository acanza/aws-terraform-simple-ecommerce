# RDS PostgreSQL Module

This Terraform module creates a managed PostgreSQL RDS instance in private subnets within a VPC, following AWS best practices for security, high availability, and operational excellence.

## Features

- **Private Subnet Deployment**: RDS instance is only accessible from within the VPC via security groups
- **Security**: 
  - Encryption at rest enabled by default
  - IAM database authentication support
  - Restrictive security groups (only allows PostgreSQL traffic from specified sources)
  - SSH key injection prevented
  - Automated backups with configurable retention
- **High Availability**: Optional Multi-AZ deployment for production
- **Monitoring**: 
  - CloudWatch Logs export for PostgreSQL logs
  - Optional Performance Insights
  - Optional Enhanced Monitoring via CloudWatch
- **Cost Optimization**: Configurable instance class and storage
- **Operational Safety**:
  - Deletion protection enabled by default
  - Final snapshots before termination
  - Parameter group management

## Usage

### Basic Example (Development)

```hcl
module "rds" {
  source = "./modules/rds"

  project_name          = "ecommerce"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnets
  
  engine_version        = "14"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  
  database_username     = "postgres"
  database_password     = var.rds_master_password  # Use Secrets Manager in production
  
  allowed_security_group_ids = [aws_security_group.app.id]
  
  multi_az = false
  skip_final_snapshot = true  # Only for dev
}
```

### Production Example

```hcl
module "rds" {
  source = "./modules/rds"

  project_name           = "ecommerce"
  environment            = "prod"
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnets
  
  engine_version         = "14"
  instance_class         = "db.t3.small"
  allocated_storage      = 100
  storage_type           = "gp3"
  
  database_username      = "postgres"
  database_password      = random_password.rds_password.result  # Better: AWS Secrets Manager
  
  allowed_security_group_ids = [
    aws_security_group.app.id,
    aws_security_group.bastion.id
  ]
  
  multi_az                         = true
  backup_retention_period          = 30
  skip_final_snapshot              = false
  enable_deletion_protection       = true
  enable_enhanced_monitoring       = true
  monitoring_interval              = 60
  enable_performance_insights      = true
  enable_iam_database_authentication = true
}
```

## Variables

### Required
- `project_name` - Project identifier (used in resource naming)
- `environment` - Environment name (dev/stage/prod)
- `vpc_id` - VPC ID where RDS will be deployed
- `private_subnet_ids` - List of at least 2 private subnet IDs (different AZs)
- `allowed_security_group_ids` - Security group IDs that can access RDS
- `database_password` - Master password (SENSITIVE - use Secrets Manager in production)

### Optional with Defaults
- `engine_version` - PostgreSQL version (default: "14")
- `instance_class` - RDS instance type (default: "db.t3.micro")
- `allocated_storage` - Storage in GB (default: 20)
- `storage_type` - Storage type gp2/gp3/io1 (default: "gp2")
- `multi_az` - Enable Multi-AZ (default: false)
- `backup_retention_period` - Days to keep backups (default: 7)
- `skip_final_snapshot` - Skip final snapshot on delete (default: false)
- `enable_storage_encryption` - Encrypt data at rest (default: true)
- `enable_iam_database_authentication` - Enable IAM auth (default: true)
- `enable_enhanced_monitoring` - Enable detailed monitoring (default: false)
- `enable_deletion_protection` - Prevent accidental deletion (default: true)

## Outputs

- `db_instance_id` - RDS instance identifier
- `db_instance_endpoint` - Full endpoint (address:port)
- `db_instance_address` - Endpoint address only
- `db_instance_port` - PostgreSQL port (5432)
- `db_instance_arn` - AWS ARN
- `db_subnet_group_id` - Subnet group ID
- `db_security_group_id` - Security group ID

## Important Notes

### Password Management
⚠️ **NEVER hardcode passwords in Terraform files or terraform.tfvars**

Recommended approaches:
1. **AWS Secrets Manager** (recommended for production):
   ```hcl
   database_password = random_password.db.result
   # Then push to Secrets Manager in a separate step
   ```

2. **Environment variables**:
   ```bash
   export TF_VAR_database_password="secure_password_here"
   terraform apply
   ```

3. **Terraform Cloud/Variables**:
   Use Terraform Cloud's sensitive variables feature

### Network Access
- RDS is deployed in **private subnets only** - no public access
- Applications must be in the same VPC to connect
- Use security groups to control traffic
- Optionally use RDS Proxy for connection pooling

### Backup Strategy
- Automated daily backups retained according to `backup_retention_period`
- Final snapshots created before deletion (unless `skip_final_snapshot=true`)
- Snapshots can be used for point-in-time recovery

### Multi-AZ Deployment
- **Development**: Set `multi_az = false` for cost savings
- **Production**: Set `multi_az = true` for automatic failover and high availability
- Failover typically takes 1-2 minutes

### Performance Insights
- Available for db.t3.small and larger instances
- Provides database performance metrics and tuning recommendations
- Additional charges may apply

## Cost Optimization

### Development Environment
```hcl
instance_class              = "db.t3.micro"
allocated_storage           = 20
multi_az                    = false
backup_retention_period     = 7
skip_final_snapshot         = true
enable_enhanced_monitoring  = false
enable_performance_insights = false
```

### Production Environment
```hcl
instance_class              = "db.t3.small"  # or larger
allocated_storage           = 100  # adjust based on needs
multi_az                    = true
backup_retention_period     = 30
skip_final_snapshot         = false
enable_enhanced_monitoring  = true
enable_performance_insights = true
```

## Troubleshooting

### Cannot connect to RDS
1. Verify security group allows inbound traffic on port 5432
2. Ensure source security group is included in `allowed_security_group_ids`
3. Check that application is in the same VPC
4. Verify NAT Gateway is configured if accessing from public resources

### RDS password change fails
- The module ignores password changes after initial creation to prevent accidental resets
- To change password: Update AWS Secrets Manager or use AWS console
- To force change in terraform: Remove `ignore_changes` and run `terraform apply`

### Storage full
- Monitor allocated storage with CloudWatch metrics
- Modify `allocated_storage` variable and run `terraform apply`
- Consider using gp3 for better performance/cost ratio

## Related Modules

- **VPC Module**: Provides VPC and private subnets for RDS deployment
- **Security Groups Module**: Can be used for more complex security group rules
- **EC2 Module**: Deploy application servers in the same VPC to connect to RDS

## References

- [AWS RDS PostgreSQL Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [AWS Well-Architected Framework - Database](https://docs.aws.amazon.com/wellarchitected/latest/userguide/welcomed.html)
- [Terraform AWS Provider RDS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
