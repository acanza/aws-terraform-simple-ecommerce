# IAM Module - Users, Roles, and Policies

Esta módulo crea usuarios y roles IAM con permisos mínimos siguiendo el principio de **menor privilegio** para un proyecto de e-commerce seguro.

## Descripción General

### Componentes

#### 1. **Rol de EC2** (`ec2_instance_role`)
A esta rol se le pueden asignar permisos mínimos necesarios para que la aplicación en EC2 funcione:
- **Secrets Manager**: Acceso de lectura a secretos de RDS (credenciales de BD)
- **CloudWatch Logs**: Escritura de logs de la aplicación
- **KMS**: Descifrado de secretos encriptados

**Permisos**:
- `secretsmanager:GetSecretValue` - Solo para secretos bajo `{namespace}/rds/*`
- `logs:CreateLogGroup,CreateLogStream,PutLogEvents` - Solo para logs específicos
- `kms:Decrypt,DescribeKey` - Restringido a Secrets Manager

#### 2. **Usuario Terraform/DevOps** (`terraform_user_name`)
Usuario IAM para gestionar la infraestructura con Terraform. Tiene permisos limitados a:
- Gestión de VPC, subnets, gateways
- Gestión de security groups
- Instancias EC2
- RDS
- IAM (solo recursos con prefijo `{namespace}-`)
- Secrets Manager (solo `{namespace}/*`)
- S3 y DynamoDB para state de Terraform

**Casos de uso**: CI/CD pipelines, administradores de infraestructura

#### 3. **Usuario SSH/SSM** (`ssh_user_name`)
Usuario IAM para acceso SSH/Session Manager a instancias EC2:
- **Systems Manager Session Manager**: Alternativa segura a SSH tradicional
- **CloudWatch Logs**: Auditoría de sesiones
- **S3**: Almacenamiento de logs de sesión

**Casos de uso**: Acceso remoto seguro a instancias, debugging

#### 4. **Grupo Read-Only** (`read_only`)
Grupo IAM para usuarios que necesitan acceso de lectura solamente.

## Variables

```hcl
variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "dev, stage, or prod"
  type        = string
}

variable "project_name" {
  description = "Project name for naming"
  type        = string
}

variable "terraform_user_name" {
  description = "Username for Terraform user"
  type        = string
  default     = "terraform-admin"
}

variable "enable_ssh_user" {
  description = "Create SSH/SSM user"
  type        = bool
  default     = true
}

variable "ssh_user_name" {
  description = "Username for SSH user"
  type        = string
  default     = "ec2-ssh-user"
}
```

## Output

La módulo export los siguientes valores:

```hcl
output "ec2_instance_profile_name"    # Para adjuntar a EC2
output "ec2_instance_profile_arn"     # ARN del instance profile
output "terraform_user_name"          # Usuario Terraform
output "terraform_user_arn"           # ARN usuario Terraform
output "ssh_user_name"                # Usuario SSH
output "ssh_user_arn"                 # ARN usuario SSH
output "read_only_group_name"         # Grupo read-only
output "read_only_group_arn"          # ARN grupo read-only
```

## Uso

### En módulo de EC2

```hcl
module "iam" {
  source = "../../modules/iam"

  region       = var.region
  environment  = var.environment
  project_name = var.project_name

  tags = {
    CostCenter = "engineering"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  # ... otras configuraciones ...
  
  iam_instance_profile = module.iam.ec2_instance_profile_name
}
```

### En environment (dev/stage/prod)

```hcl
module "iam" {
  source = "../../modules/iam"

  region       = var.region
  environment  = "dev"
  project_name = "ecommerce"

  terraform_user_name = "terraform-admin"
  enable_ssh_user      = true

  tags = {
    CostCenter = "engineering"
  }
}
```

## Seguridad

### Principios aplicados

1. **Menor Privilegio**: Solo permisos explícitamente necesarios
2. **Segregación**: Usuarios diferentes para roles diferentes
3. **Namespacing**: Permisos limitados a recursos con prefijo de proyecto/env
4. **Restricciones de Recurso**: ARNs específicas en lugar de wildcards
5. **Auditoría**: Logs en CloudWatch y S3 para acceso

### Mejores Prácticas

- Usar keys de acceso AWS para el usuario Terraform
- Rotar keys regularmente
- Usar MFA para usuarios con acceso privilegiado
- Session Manager en lugar de SSH directo cuando sea posible
- Monitorear actividad IAM con CloudTrail

## Próximos Pasos

1. **Adjuntar instance profile a EC2**:
   ```hcl
   iam_instance_profile = module.iam.ec2_instance_profile_name
   ```

2. **Crear keys de acceso para usuario Terraform**:
   ```bash
   aws iam create-access-key --user-name terraform-admin
   ```

3. **Registrar keys en CI/CD**:
   - GitHub Actions secrets
   - GitLab CI variables
   - Jenkins credentials

4. **Crear secretos en Secrets Manager**:
   ```bash
   aws secretsmanager create-secret \
     --name ecommerce-dev/rds/master-password \
     --secret-string $(openssl rand -base64 32)
   ```

5. **Habilitar CloudTrail** para auditoría completa

## Notas

- El módulo NO crea keys de acceso automáticamente (debe hacerse manualmente)
- Los permisos de Terraform pueden ajustarse según necesidades específicas
- Session Manager requiere IAM role con SSM managed policies
