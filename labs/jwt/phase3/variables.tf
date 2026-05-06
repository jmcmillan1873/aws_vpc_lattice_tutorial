# =============================================================================
# Phase 3: Input Variables
# =============================================================================
# These variables accept outputs from Phase 1 (infrastructure) and Phase 2
# (container image URIs). They wire Phase 3 resources to the base infrastructure
# without hard-coding any resource identifiers.
#
# Unlike the VPC Lattice lab, there is no ecs_infrastructure_role_arn or vpc_id
# variable because this lab has no Lattice target group registration.
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region - must match the region used in Phase 1"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Naming prefix for all resources (must match Phase 1 prefix)"
  type        = string
  default     = "jwt-lab"
}

# -----------------------------------------------------------------------------
# Network - from Phase 1 outputs
# -----------------------------------------------------------------------------

# Used in ECS task networking (awsvpcConfiguration) for all task definitions
variable "subnet_id" {
  description = "Public subnet ID from Phase 1 (aws_subnet.public.id)"
  type        = string
}

# -----------------------------------------------------------------------------
# Security Groups - from Phase 1 outputs
# -----------------------------------------------------------------------------

# Attached to Service_A and Service_C tasks (egress-only, no inbound)
variable "callers_security_group_id" {
  description = "Security group ID for caller tasks from Phase 1 (egress-only)"
  type        = string
}

# Attached to Service_B ECS service (allows inbound TCP 5000 from callers SG)
variable "service_b_security_group_id" {
  description = "Security group ID for Service_B from Phase 1 (inbound on 5000 from callers)"
  type        = string
}

# -----------------------------------------------------------------------------
# IAM Roles - from Phase 1 outputs
# -----------------------------------------------------------------------------

# Shared execution role used by all task definitions for ECR pull and log writes
variable "task_execution_role_arn" {
  description = "Task execution role ARN from Phase 1 (ECR pull + CloudWatch Logs)"
  type        = string
}

# Task role for Service_A - no special permissions (structural parity)
variable "service_a_task_role_arn" {
  description = "Service_A task role ARN from Phase 1 (no special permissions)"
  type        = string
}

# Task role for Service_B - no special permissions (structural parity)
variable "service_b_task_role_arn" {
  description = "Service_B task role ARN from Phase 1 (no special permissions)"
  type        = string
}

# Task role for Service_C - no special permissions (structural parity)
variable "service_c_task_role_arn" {
  description = "Service_C task role ARN from Phase 1 (no special permissions)"
  type        = string
}

# -----------------------------------------------------------------------------
# Container Image URIs - from Phase 2 (docker build + push)
# -----------------------------------------------------------------------------

# Image used by both Service_A and Service_C task definitions (same code, different env vars)
variable "caller_image_uri" {
  description = "ECR image URI for the caller container (from Phase 2 docker push)"
  type        = string
}

# Image used by Service_B task definition
variable "service_b_image_uri" {
  description = "ECR image URI for the Service_B container (from Phase 2 docker push)"
  type        = string
}

# -----------------------------------------------------------------------------
# JWT Configuration
# -----------------------------------------------------------------------------

# Shared HMAC signing key passed to all containers via environment variable.
# In production, services would NOT share signing keys — this is a lab
# simplification documented in the tutorial.
variable "jwt_secret" {
  description = "Shared HMAC signing key for JWT generation and validation (lab simplification)"
  type        = string
  sensitive   = true
}
