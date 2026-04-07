.PHONY: help init plan apply destroy fmt validate lint

# Default environment (can be overridden: make plan ENV=prod)
ENV ?= dev

help:
	@echo "Terraform Makefile targets:"
	@echo ""
	@echo "Build Commands:"
	@echo "  make init       - Initialize Terraform in envs/dev"
	@echo "  make fmt        - Format all Terraform files"
	@echo "  make validate   - Validate Terraform configuration"
	@echo "  make lint       - Run tflint on modules"
	@echo ""
	@echo "Execution Commands (default: dev environment):"
	@echo "  make plan       - Plan infrastructure changes (envs/dev)"
	@echo "  make apply      - Apply infrastructure changes (envs/dev)"
	@echo "  make destroy    - Destroy infrastructure (envs/dev)"
	@echo ""
	@echo "Advanced:"
	@echo "  make plan ENV=prod       - Plan production changes"
	@echo "  make apply ENV=stage     - Apply to staging environment"

# Initialize Terraform in the development environment
init:
	cd envs/dev && terraform init

# Plan infrastructure changes
plan:
	@echo "Planning infrastructure changes in envs/$(ENV)..."
	cd envs/$(ENV) && terraform plan -out=tfplan

# Apply infrastructure changes
apply:
	@echo "Applying infrastructure changes in envs/$(ENV)..."
	cd envs/$(ENV) && terraform apply tfplan

# Destroy infrastructure
destroy:
	@echo "WARNING: This will destroy all infrastructure in envs/$(ENV)"
	cd envs/$(ENV) && terraform destroy

# Format Terraform files recursively
fmt:
	@echo "Formatting all Terraform files..."
	terraform fmt -recursive

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	cd envs/dev && terraform validate

# Lint Terraform code
lint:
	@echo "Linting Terraform modules..."
	tflint
