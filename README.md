# AWS infrastructure for ecommerce web

> **Learning project.** The goal is to explore and practise deploying AWS infrastructure with Terraform. Only the `dev` environment has been implemented; `stage` and `prod` exist as directory stubs but are not deployed.

## Implemented infrastructure

The architecture deploys a [Medusa](https://medusajs.com/) headless commerce backend together with a Next.js storefront (Medusa Starter Storefront), all on AWS in the `eu-west-3` (Paris) region.

### Terraform modules

| Module | Main resource | Description |
|---|---|---|
| `vpc` | VPC `10.0.0.0/16` | Base network with 2 public and 2 private subnets spread across 2 different AZs |
| `security_groups` | Security Groups | Access rules for EC2, RDS and the App Runner VPC Connector |
| `iam` | Roles & IAM Users | Least-privilege permissions for Terraform and SSH access to EC2 |
| `ec2` | EC2 `t4g.small` | Medusa Commerce backend in public subnet 1; Nginx reverse proxy on port 9000 |
| `rds` | RDS PostgreSQL 14 `db.t3.micro` | Database in a private subnet; accessible only from the EC2 Security Group |
| `app-runner` | AWS App Runner + ECR | Next.js storefront container; connects to the backend via VPC Connector in private subnets |

### Architecture diagram

![Architecture diagram](docs/aws-medusa-ecommerce-diagram.svg)

### Note on availability (HA)

In `dev`, both the EC2 instance and the RDS instance are deployed in the **same AZ**, with a single instance of each (`multi_az = false`), which reduces costs during testing. The VPC has been designed with **2 public and 2 private subnets in different AZs** so that the `stage` and `prod` environments can enable high availability (Multi-AZ RDS, Auto Scaling Groups, etc.) without changes to the base network.

### Monitoring

Basic CloudWatch alarms (CPU, RDS status, etc.) are created and published to an SNS topic that can be configured using the `alarm_email` variable.
