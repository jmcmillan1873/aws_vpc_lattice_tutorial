# =============================================================================
# Phase 3: ECS Services and VPC Lattice - Provider Configuration
# =============================================================================
# This file configures the AWS provider for Phase 3. Phase 3 deploys ECS task
# definitions, the Service_B ECS service, and all VPC Lattice resources
# (service network, service, listener, target group, auth policy).
#
# Phase 3 depends on outputs from Phase 1 (network, IAM, security groups) and
# Phase 2 (container image URIs pushed to ECR).
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform and Provider Configuration
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS provider using the region variable.
# Must match the region used in Phase 1 so resources can reference each other.
provider "aws" {
  region = var.aws_region
}
