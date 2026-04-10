variable "bucket_name" {
  description = "Nombre del bucket S3 para almacenar imágenes"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9\\-]{3,63}$", var.bucket_name))
    error_message = "El nombre del bucket debe tener 3-63 caracteres, solo minúsculas, números y guiones."
  }
}

variable "environment" {
  description = "Ambiente (dev, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "El ambiente debe ser: dev, stage, o prod."
  }
}

variable "enable_versioning" {
  description = "Habilitar versionamiento de objetos en el bucket"
  type        = bool
  default     = true
}

variable "enable_server_side_encryption" {
  description = "Habilitar encriptación del lado del servidor (SSE-S3)"
  type        = bool
  default     = true
}

variable "read_access_role_arns" {
  description = "Lista de ARNs de roles IAM que pueden leer desde el bucket"
  type        = list(string)
  default     = []
}

variable "write_access_role_arns" {
  description = "Lista de ARNs de roles IAM que pueden escribir en el bucket"
  type        = list(string)
  default     = []
}

variable "lifecycle_expiration_days" {
  description = "Días para eliminar objetos automáticamente (0 = deshabilitado)"
  type        = number
  default     = 0

  validation {
    condition     = var.lifecycle_expiration_days >= 0
    error_message = "lifecycle_expiration_days debe ser mayor o igual a 0."
  }
}

variable "tags" {
  description = "Tags adicionales para el bucket"
  type        = map(string)
  default     = {}
}
