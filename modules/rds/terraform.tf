terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Note: Provider configuration is inherited from the calling workspace.
# This module does not define its own provider block to allow use with
# count, for_each, and to enable flexible provider composition.

