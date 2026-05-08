# aws-terraform-simple-ecommerce

> **Proyecto de prueba.** El objetivo es explorar y practicar el despliegue de infraestructura AWS con Terraform. Solo se ha implementado el entorno `dev`; los entornos `stage` y `prod` están reservados como estructura pero no desplegados.

## Infraestructura implementada

La arquitectura despliega un e-commerce basado en [Medusa](https://medusajs.com/) (backend headless) con un storefront Next.js (Medusa Starter Storefront), todo en AWS sobre la región `eu-west-3` (París).

### Módulos Terraform

| Módulo | Recurso principal | Descripción |
|---|---|---|
| `vpc` | VPC `10.0.0.0/16` | Red base con 2 subredes públicas y 2 privadas distribuidas en 2 AZs distintas |
| `security_groups` | Security Groups | Reglas de acceso para EC2, RDS y App Runner VPC Connector |
| `iam` | Roles e IAM Users | Permisos mínimos para Terraform y acceso SSH a EC2 |
| `ec2` | EC2 `t4g.small` | Backend Medusa Commerce en subred pública 1; Nginx como proxy inverso en el puerto 9000 |
| `rds` | RDS PostgreSQL 14 `db.t3.micro` | Base de datos en subred privada; acceso exclusivo desde el Security Group de EC2 |
| `app-runner` | AWS App Runner + ECR | Storefront Next.js en contenedor; se conecta al backend vía VPC Connector en subredes privadas |

### Diagrama de la arquitectura

```
Internet
    │
    ├─ HTTPS ──► App Runner (storefront Next.js)
    │                  │  VPC Connector (subredes privadas)
    │                  ▼
    ├─ HTTP/SSH ──► EC2 t4g.small (Medusa backend · puerto 9000)
    │               Subred pública – AZ 1
    │                  │
    │                  ▼
    └──────────────► RDS PostgreSQL 14 (db.t3.micro)
                      Subred privada – AZ 1
```

### Nota sobre disponibilidad (HA)

En `dev` tanto la instancia EC2 como RDS se despliegan en la **misma AZ** y con una única instancia cada una (`multi_az = false`), lo que reduce costes durante las pruebas. La VPC se ha diseñado con **2 subredes públicas y 2 privadas en AZs diferentes** para que los entornos `stage` y `prod` puedan activar alta disponibilidad (Multi-AZ RDS, Auto Scaling Groups, etc.) sin cambios en la red base.

### Monitorización

Se crean alarmas CloudWatch básicas (CPU, estado RDS, etc.) publicadas en un topic SNS configurable mediante la variable `alarm_email`.

## Estructura del repositorio

```
modules/          # Módulos Terraform reutilizables
  vpc/
  security_groups/
  iam/
  ec2/
  rds/
  app-runner/
envs/
  dev/            # Único entorno desplegado
  stage/          # Reservado (no desplegado)
  prod/           # Reservado (no desplegado)
docs/             # Documentación técnica y guías
Makefile          # Targets: fmt · validate · plan · apply
```

## Comandos habituales

```bash
make fmt        # Formatea el código al estilo canónico
make validate   # Valida la configuración (sin llamadas a AWS)
make plan       # Muestra los cambios previstos (solo lectura)
```

