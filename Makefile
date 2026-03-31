.PHONY: help init plan apply destroy fmt validate

help:
	@echo "Terraform Makefile targets:"
	@echo "  make init       - Initialize Terraform"
	@echo "  make plan       - Plan infrastructure changes"
	@echo "  make apply      - Apply infrastructure changes"
	@echo "  make destroy    - Destroy infrastructure"
	@echo "  make fmt        - Format Terraform files"
	@echo "  make validate   - Validate Terraform configuration"

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

destroy:
	terraform destroy

fmt:
	terraform fmt -recursive

validate:
	terraform validate
