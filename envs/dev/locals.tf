# Local values for Medusa Commerce configuration
locals {
  # Determine RDS endpoint
  # Use the actual RDS module output (EC2 will be created after RDS)
  db_host = var.medusa_db_host != "" ? var.medusa_db_host : module.rds[0].db_instance_address

  # Medusa initialization script - read and replace placeholders
  # We use a simple replacement approach instead of templatefile to avoid conflicts with bash variables
  medusa_user_data = base64encode(replace(
    replace(
      replace(
        replace(
          replace(
            file("${path.module}/medusa-init.sh"),
            "%%DB_HOST%%", local.db_host
          ),
          "%%DB_NAME%%", var.medusa_database_name
        ),
        "%%DB_USER%%", "postgres"
      ),
      "%%DB_PASSWORD%%", var.rds_master_password
    ),
    "%%ADMIN_USER%%", var.medusa_admin_user
  ))
}
