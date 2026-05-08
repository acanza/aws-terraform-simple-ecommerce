# Security Groups Design - Assumptions & Risk Assessment

> **Última actualización**: 5 de mayo de 2026  
> **Versión**: 2.1 — Arquitectura Medusa + App Runner

## Architecture Overview

```
┌───────────────────────────────────────────────────────────────────┐
│                     Internet / Users                               │
└──────────────┬──────────────────────────────┬─────────────────────┘
               │ HTTPS (App Runner URL)        │ HTTP/HTTPS directo
               │                              │ (enable_http/https = true por defecto)
   ┌───────────▼──────────┐       ┌───────────▼──────────────────────┐
   │  AWS App Runner       │       │      Internet Gateway             │
   │  (Next.js Storefront) │       └───────────┬──────────────────────┘
   │  SG: app-runner-sg    │                   │
   │  Egress:              │    ┌──────────────▼────────────────────────────┐
   │  - Port 9000 → EC2 SG │    │              VPC (10.0.0.0/16)            │
   │  - HTTPS 443 → internet│   │                                           │
   └───────────┬───────────┘    │  ┌────────────────────────────────────┐   │
               │ VPC Connector  │  │         Public Subnets              │   │
               │ (private nets) │  │      (eu-west-3a, eu-west-3b)      │   │
               │                │  │                                    │   │
   ┌───────────▼────────────────▼──▼  EC2 (Medusa Commerce API)        │   │
   │                                  SG: ec2-sg                        │   │
   │  Ingress:                                                          │   │
   │  - Port 9000 from app-runner-sg (VPC interno)                      │   │
   │  - Port 9000 from medusa_api_cidr (workstation opt. /32)           │   │
   │  - Port 80  from 0.0.0.0/0 (enable_http = true por defecto ⚠️)    │   │
   │  - Port 443 from 0.0.0.0/0 (enable_https = true por defecto ⚠️)   │   │
   │  - SSH from trusted_ssh_cidr (opcional, null por defecto)          │   │
   │  Egress:                                                           │   │
   │  - Port 5432 → rds-sg                                              │   │
   │  - Port 443 → 0.0.0.0/0 (npm, APIs externas vía NAT)              │   │
   │  - Port 53 UDP → 0.0.0.0/0 (DNS)                                  │   │
   └────────────────────────────┬───────────────────────────────────────┘   │
                                │                                           │
                ┌───────────────▼────────────────────────────┐              │
                │              Private Subnets                │              │
                │           (eu-west-3a, eu-west-3b)         │              │
                │                                            │              │
                │  RDS PostgreSQL        NAT Gateway         │              │
                │  SG: rds-sg                                │              │
                │  Ingress:                                  │              │
                │  - Port 5432 from ec2-sg solamente         │              │
                │  Egress: ninguno                           │              │
                └────────────────────────────────────────────┘              │
                                                └──────────────────────────┘
```

### Security Groups Summary

| SG | Recurso | Reglas Ingress | Reglas Egress |
|----|---------|----------------|---------------|
| `ec2-sg` | EC2 Medusa API | port 9000 (app-runner-sg), port 9000 (medusa_api_cidr opt.), port 80 (enable_http **true** por defecto), port 443 (enable_https **true** por defecto), SSH (opt.) | port 5432 (rds-sg), port 443 (HTTPS), port 53 UDP (DNS) |
| `rds-sg` | RDS PostgreSQL | port 5432 (ec2-sg) | ninguno |
| `app-runner-sg` | App Runner VPC Connector | ninguno | port 9000 (ec2-sg), port 443 (internet) |

---

## 📋 Design Assumptions

### 1. **Architecture Type: Multi-Tier (Storefront + API + Database)**
   - **Estado**: ✅ Implementado
   - **Componentes activos**:
     - App Runner (Next.js SSR/Storefront) → **SG: `app-runner-sg`**
     - EC2 (Medusa Commerce API, puerto 9000) → **SG: `ec2-sg`** (en subred pública)
     - RDS PostgreSQL (base de datos privada) → **SG: `rds-sg`**
   - **Total SGs**: 3 (ec2-sg, rds-sg, app-runner-sg)
   - **Cambio respecto a v1**: Anteriormente 2 SGs (ec2-sg, rds-sg); se añadió `app-runner-sg` para el VPC Connector de App Runner

### 2. **Aplicación: Medusa Commerce (antes WordPress)**
   - **Estado**: ✅ Migración completada (2026-04-20)
   - **Impacto en SGs**: Puerto de API expuesto es 9000 (Medusa), no 80/8080
   - **Base de datos**: PostgreSQL puerto 5432 (antes MySQL 3306)
   - **Arquitectura headless**: El frontend (Next.js) consume la API de Medusa vía VPC Connector

### 3. **EC2 Web Traffic: HTTP/HTTPS (HABILITADO por defecto ⚠️)**
   - **Estado actual**: `enable_http = true` y `enable_https = true` en `envs/dev/variables.tf`
   - **Impacto**: EC2 en subred pública acepta tráfico HTTP/HTTPS desde `0.0.0.0/0` por defecto
   - **Justificación dev**: Acceso directo a Medusa API y admin dashboard (`/app`) sin pasar por App Runner
   - **Riesgo**: EC2 está expuesto directamente a internet — ver Risk Assessment
   - **Para producción**: Deshabilitar ambos (`false`) y usar App Runner como único punto de entrada público

### 4. **Puerto Medusa API (9000): Acceso Controlado**
   - **Estado**: ✅ Implementado
   - **Regla principal**: Puerto 9000 accesible desde `app-runner-sg` (referencia SG interna, sin exposición pública)
   - **Regla opcional (workstation)**: Variable `medusa_api_cidr` permite abrir el puerto 9000 desde una IP de confianza (e.g. workstation `/32`) para debug o Docker build
   - **Nunca usar**: `0.0.0.0/0` para `medusa_api_cidr`
   - **Migración planificada**: `ec2_medusa_api` (regla workstation) reemplazable por VPC Connector completo cuando App Runner esté siempre activo

### 5. **SSH Access: BLOQUEADO por defecto**
   - **Assumption**: SSH completamente deshabilitado para máxima seguridad
   - **Implementación**: Sin regla SSH; opcional vía variable `trusted_ssh_cidr` (default: null)
   - **Para habilitar SSH**: Definir `trusted_ssh_cidr = "203.0.113.0/32"` (IP de oficina/VPN)
   - **Alternativa recomendada**: AWS Systems Manager Session Manager (sin SSH abierto)

### 6. **RDS Access: Exclusivo al EC2 Security Group**
   - **Estado**: ✅ Sin cambio vs v1
   - **Puerto**: 5432 (PostgreSQL) — antes 3306 (MySQL)
   - **Acceso**: Solo desde `ec2-sg` vía referencia de SG
   - **Seguridad**: Base de datos inaccesible desde internet o App Runner (App Runner solo habla con EC2, no con RDS directamente)

### 7. **EC2 Egress: Restringido (Fix P1 aplicado)**
   - **Estado**: ✅ SECURITY FIX P1 aplicado — ya no es "allow all"
   - **Reglas actuales**:
     - Puerto 5432 → `rds-sg` (referencia SG, no CIDR)
     - Puerto 443 → `0.0.0.0/0` (npm registry, APIs externas vía NAT)
     - Puerto 53 UDP → `0.0.0.0/0` (resolución DNS)
   - **Cambio respecto a v1**: Antes era `ALL → 0.0.0.0/0`; ahora 3 reglas explícitas

### 8. **App Runner VPC Connector: SG Dedicado**
   - **Estado**: ✅ Implementado
   - **Propósito**: Enrutar tráfico App Runner → EC2 dentro del VPC (sin pasar por internet público)
   - **SG `app-runner-sg` egress**:
     - Puerto 9000 → `ec2-sg` (referencia interna; tráfico VPC-interno)
     - Puerto 443 → `0.0.0.0/0` (Stripe, CDN, APIs externas vía NAT Gateway)
   - **Por qué subredes privadas**: El tráfico a internet sale por NAT Gateway; las subredes privadas tienen ruta NAT

### 9. **RDS Egress: Sin Reglas (Deny-by-Default)**
   - **Estado**: ✅ Sin cambio vs v1
   - **Why**: Las bases de datos no necesitan acceso saliente a internet

### 10. **Reglas Separadas (No Inline)**
   - **Estado**: ✅ Sin cambio vs v1
   - **Recursos usados**: `aws_vpc_security_group_ingress_rule` y `aws_vpc_security_group_egress_rule`
   - **Why**: Mejor legibilidad, control granular, compatible con imports/drift detection

### 11. **Single Environment: Dev solamente**
   - **Estado**: Sin cambio vs v1
   - **Para Producción**: Añadir VPC Endpoints (S3, Secrets Manager), ALB, restricciones de egress adicionales

---

## ⚠️ Risk Assessment

### 🔴 CRITICAL RISKS

**1. SSH exposure (MITIGADO)**
   - **Riesgo**: SSH puede habilitarse via `trusted_ssh_cidr`; si se usa CIDR amplio es crítico
   - **Severidad**: MITIGADO (sin regla SSH por defecto; se crea solo si `trusted_ssh_cidr != null`)
   - **Estado**: ✅ Seguro por defecto

**2. HTTP/HTTPS directo a EC2 (ACTIVO POR DEFECTO)**
   - **Riesgo**: EC2 en subred pública acepta HTTP/HTTPS desde `0.0.0.0/0` — expuesto directamente a internet
   - **Severidad**: CRÍTICO si Medusa tiene vulnerabilidades sin parchear
   - **Estado actual**: `enable_http = true`, `enable_https = true` en `variables.tf` (defaults)
   - **Justificación dev**: Acceso directo al admin dashboard y API durante desarrollo
   - **Para producción**: Cambiar defaults a `false`; enrutar todo vía App Runner
   - **Estado**: ⚠️ ACTIVO — riesgo conocido y aceptado para dev

**3. Puerto Medusa 9000 desde workstation (si `medusa_api_cidr` habilitado)**
   - **Riesgo**: El puerto 9000 queda accesible desde una IP pública si `medusa_api_cidr` se define
   - **Severidad**: CRÍTICO si se usa `0.0.0.0/0`; BAJO con `/32`
   - **Validación**: Variable valida CIDR válido; el operador debe asegurar `/32`
   - **Plan de migración**: Reemplazar por acceso exclusivo vía App Runner VPC Connector en producción
   - **Estado**: ⚠️ Solo habilitar temporalmente; usar `/32` siempre

### 🟠 HIGH RISKS

**1. EC2 → Internet HTTPS (0.0.0.0/0 puerto 443)**
   - **Riesgo**: EC2 puede alcanzar cualquier IP externa; posible vector de exfiltración de datos
   - **Severidad**: ALTO en prod; ACEPTABLE en dev
   - **Por qué existe**: npm registry, Medusa plugins, actualizaciones del SO
   - **Mitigación para prod**: Añadir VPC Endpoint S3 + limitar 443 a rangos conocidos
   - **Estado**: ⚠️ Trade-off conocido para dev

**2. EC2 comprometido = acceso a RDS**
   - **Riesgo**: Un EC2 comprometido permite acceso directo a PostgreSQL
   - **Severidad**: ALTO (típico de arquitectura de dos capas)
   - **Mitigación**: Hardening del SO en EC2; contraseña RDS en Secrets Manager; RDS encryption en reposo
   - **Estado**: ⚠️ Limitación arquitectónica

**3. EC2 root volume sin encriptación (pendiente)**
   - **Riesgo**: Datos en el disco del servidor Medusa no cifrados
   - **Severidad**: CRÍTICO (auditado 2026-04-13, aún pendiente)
   - **Solución**: `encrypted = true` en `modules/ec2/main.tf`
   - **Estado**: ❌ P0 PENDIENTE

**4. VPC Flow Logs deshabilitados (pendiente)**
   - **Riesgo**: Sin auditoría de tráfico real; difícil detectar movimientos laterales
   - **Severidad**: CRÍTICO para compliance
   - **Solución**: Añadir `aws_flow_log` a `modules/vpc/main.tf`
   - **Estado**: ❌ P0 PENDIENTE

### 🟡 MEDIUM RISKS

**1. App Runner → NAT Gateway (egress HTTPS a internet)**
   - **Riesgo**: App Runner puede alcanzar cualquier servicio externo vía puerto 443
   - **Severidad**: MEDIO (necesario para Stripe, CDN, APIs externas)
   - **Por qué el egress HTTPS existe**: `egress_type = VPC` fuerza todo el tráfico por el VPC; sin esta regla App Runner no puede contactar servicios externos
   - **Estado**: ⚠️ Aceptable; limitar con VPC Endpoints en prod

**2. HTTP (puerto 80) → tráfico en texto plano (si se habilita)**
   - **Riesgo**: Credenciales/datos sin cifrar
   - **Mitigación**: Usar siempre HTTPS; redirigir HTTP→HTTPS en la aplicación
   - **Estado**: ⚠️ Responsabilidad de la aplicación

**3. Sin RDS CloudWatch Logs cuando RDS activo**
   - **Riesgo**: Sin visibilidad de queries lentas o conexiones anómalas
   - **Severidad**: MEDIO (auditado 2026-04-13; módulo RDS tiene `enable_enhanced_monitoring = true`)
   - **Estado**: ⚠️ Parcialmente mitigado; añadir `enabled_cloudwatch_logs_exports = ["postgresql"]`

### 🟢 LOW RISKS

**1. Single NAT Gateway (SPOF para dev)**
   - **Riesgo**: Si NAT Gateway falla, App Runner pierde acceso a internet externo; EC2 pierde acceso a npm/S3
   - **Severidad**: BAJO para dev (2-5 min de downtime); ALTO para prod
   - **Estado**: ✅ Aceptable para dev; Multi-NAT obligatorio en prod

**2. Sin rotación de SSH keys (solo si SSH habilitado)**
   - **Riesgo**: EC2 Key Pairs de larga duración si SSH está activo
   - **Mitigación**: Preferir SSM Session Manager; si SSH es necesario, implementar rotación
   - **Estado**: ⏳ Mejora futura

**3. Sin VPC Endpoints para Secrets Manager**
   - **Riesgo**: El tráfico App Runner→internet sale por NAT (costo + latencia)
   - **Severidad**: BAJO para dev (funcional pero subóptimo)
   - **Estado**: ⏳ Mejora futura (VPC Endpoints casi gratis + mejor seguridad)

---

## 🔐 Overly Permissive Access Assessment

### Configuración Actual (si se usa correctamente)

⚠️ **La configuración actual (dev) tiene permisos amplios en HTTP/HTTPS**:
- ✅ SSH: BLOQUEADO por defecto (habilitar solo con `trusted_ssh_cidr`)
- ⚠️ HTTP a EC2: **HABILITADO por defecto** (`enable_http = true`) — EC2 expuesto a internet
- ⚠️ HTTPS a EC2: **HABILITADO por defecto** (`enable_https = true`) — EC2 expuesto a internet
- ✅ RDS: Solo desde `ec2-sg` (no internet, no App Runner directamente)
- ✅ Medusa API 9000: Solo desde `app-runner-sg` (VPC interno) + workstation opcional (`/32`)
- ✅ EC2 egress: Restringido (443, 5432, 53) — ya no es "allow all"
- ✅ App Runner egress: Solo puerto 9000 a `ec2-sg` + 443 a internet

### Problemas potenciales (si se configura mal)

❌ **Sería excesivamente permisivo si:**
1. SSH con `trusted_ssh_cidr = "0.0.0.0/0"` (manual override)
2. `medusa_api_cidr = "0.0.0.0/0"` (puerto 9000 público)
3. `enable_http = true` en aplicación sin hardening
4. `enable_https = true` sin TLS/HTTPS forzado
5. Puerto RDS abierto a `0.0.0.0/0` (error manual en reglas)

### Mitigaciones

- ✅ Variables validadas (CIDR syntax, boolean flags)
- ✅ Recursos de reglas separados (previene modificaciones inline accidentales)
- ✅ Referencia SG para RDS y App Runner (no CIDRs)
- ⚠️ Override manual aún posible (responsabilidad del operador)
- ⏳ Futuro: AWS Security Hub + Config rules para drift detection

---

## 📊 Implementation Checklist

### Antes de `terraform plan`:

- [ ] (OPCIONAL) ¿Necesitas SSH? (deshabilitado por defecto)
  ```bash
  # Solo si se requiere SSH: obtener IP pública
  curl https://ifconfig.me
  # Ejemplo: 203.0.113.42 → usar como 203.0.113.42/32
  ```

- [ ] ¿Necesitas acceso directo al puerto Medusa 9000 desde workstation? (debug / Docker build)
  ```bash
  # Solo temporal y con /32
  medusa_api_cidr = "203.0.113.42/32"
  # Retirar una vez App Runner VPC Connector esté operativo
  ```

- [ ] Decide: ¿Habilitar HTTP o HTTPS directo a EC2?
  - [ ] No (default, más seguro) → dejar `enable_http = false`, `enable_https = false`
  - [ ] Sí, solo HTTP → `enable_http = true`
  - [ ] Sí, HTTPS (recomendado) → `enable_https = true` + `enable_http = true` (redirect)

- [ ] Confirmar puerto de base de datos
  - [ ] PostgreSQL (5432) → `db_port = 5432` ✅ (configuración actual del proyecto)

### terraform.tfvars (dev) — configuración actual real:

```hcl
region            = "eu-west-3"
vpc_cidr          = "10.0.0.0/16"
db_port           = 5432           # PostgreSQL

# SSH deshabilitado por defecto; descomentar SOLO si es necesario:
# trusted_ssh_cidr = "203.0.113.0/32"

# Puerto 9000 workstation SOLO durante debug/build; null el resto del tiempo:
# medusa_api_cidr = "203.0.113.42/32"

# ⚠️ Por defecto en variables.tf: enable_http = true, enable_https = true
# Necesario en dev para acceder al admin dashboard directamente.
# Para una postura más segura en dev, sobreescribir con false:
# enable_http  = false
# enable_https = false
```

### Output esperado de Terraform (configuración mínima, sin opcionales):

```
Plan: N to add, 0 to change, 0 to destroy

+ aws_security_group.ec2
+ aws_security_group.rds
+ aws_security_group.app_runner
+ aws_vpc_security_group_ingress_rule.ec2_from_app_runner  (puerto 9000 interno)
+ aws_vpc_security_group_ingress_rule.ec2_medusa_api       (si medusa_api_cidr != null)
+ aws_vpc_security_group_ingress_rule.ec2_ssh              (si trusted_ssh_cidr != null)
+ aws_vpc_security_group_ingress_rule.ec2_http             (si enable_http = true)
+ aws_vpc_security_group_ingress_rule.ec2_https            (si enable_https = true)
+ aws_vpc_security_group_ingress_rule.rds_from_ec2
+ aws_vpc_security_group_egress_rule.ec2_to_rds
+ aws_vpc_security_group_egress_rule.ec2_to_s3
+ aws_vpc_security_group_egress_rule.ec2_dns
+ aws_vpc_security_group_egress_rule.app_runner_to_ec2
+ aws_vpc_security_group_egress_rule.app_runner_to_https
```

---

## 🎯 Summary

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| **SSH Access** | ✅ SEGURO | Bloqueado por defecto, habilitar solo con `/32` |
| **Web Traffic directo a EC2** | ⚠️ ACTIVO | `enable_http = true`, `enable_https = true` por defecto — EC2 expuesto a internet en dev |
| **Medusa API 9000** | ✅ SEGURO | Solo desde App Runner SG (interno) + workstation opcional `/32` |
| **RDS Aislado** | ✅ SEGURO | Solo accesible desde `ec2-sg` |
| **EC2 Egress** | ✅ RESTRINGIDO | Solo 443 (HTTPS), 5432 (RDS), 53 UDP (DNS) — fix P1 aplicado |
| **App Runner Egress** | ✅ MÍNIMO | Solo 9000 → EC2 + 443 → internet |
| **Arquitectura** | ✅ MULTI-TIER | 3 SGs (ec2, rds, app-runner), bien separados |
| **Mantenibilidad** | ✅ BUENA | Recursos de reglas separados, variables parametrizadas |

### Vulnerabilidades P0 Pendientes (de auditoría 2026-04-13)

| # | Vulnerabilidad | Módulo | Estado |
|---|---------------|--------|--------|
| 1 | EC2 root volume sin encriptación | `modules/ec2/main.tf` | ❌ Pendiente |
| 2 | VPC Flow Logs deshabilitados | `modules/vpc/main.tf` | ❌ Pendiente |
| 3 | RDS sin CloudWatch Logs exports | `modules/rds/main.tf` | ❌ Pendiente |

---

## 🔄 Next Steps (Out of Scope)

1. **P0**: EC2 EBS encryption (`encrypted = true` en `modules/ec2/main.tf`)
2. **P0**: VPC Flow Logs → CloudWatch (`aws_flow_log` en `modules/vpc/main.tf`)
3. **P0**: RDS CloudWatch exports (`enabled_cloudwatch_logs_exports = ["postgresql"]`)
4. **P1**: VPC Endpoints para Secrets Manager (elimina dependencia de NAT)
5. **P2**: SSM Session Manager como alternativa a SSH (sin puerto 22 abierto)
6. **P3**: Multi-NAT Gateway para alta disponibilidad (requerido en prod)
7. **P3**: AWS Security Hub + Config rules para drift detection automático

---

**Módulo Creado**: Security Groups v1.0 — Marzo 2026  
**Módulo Actualizado**: v2.0 — App Runner + Medusa — Mayo 2026  
**Reversibilidad**: 100% (sin cambios destructivos en esta versión)
