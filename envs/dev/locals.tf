# Local values for WordPress configuration
locals {
  # Determine RDS endpoint
  db_host = var.wordpress_db_host != "" ? var.wordpress_db_host : "ecommerce-dev-postgres.${var.region}.rds.amazonaws.com"

  # WordPress user data script - read and replace placeholders
  # We use a simple replacement approach instead of templatefile to avoid conflicts with bash variables
  wordpress_user_data = base64encode(replace(
    replace(
      replace(
        replace(
          replace(
            file("${path.module}/wordpress-init.sh"),
            "%%DB_HOST%%", local.db_host
          ),
          "%%DB_NAME%%", var.wordpress_database_name
        ),
        "%%DB_USER%%", "postgres"
      ),
      "%%DB_PASSWORD%%", var.rds_master_password
    ),
    "%%ADMIN_USER%%", var.wordpress_admin_user
  ))
}
