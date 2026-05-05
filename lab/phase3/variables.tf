# =============================================================================
# Phase 3: Input Variables
# =============================================================================
# These variables accept outputs from Phase 1 (infrastructure) and Phase 2
# (container image URIs). They wire Phase 3 resources to the base infrastructure
# without hard-coding any resource identifiers.
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
  default     = "lab"
}

# -----------------------------------------------------------------------------
# Network - from Phase 1 outputs
# -----------------------------------------------------------------------------

# Used to associate the VPC with the Lattice Service Network
variable "vpc_id" {
  description = "VPC ID from Phase 1 (aws_vpc.main.id)"
  type        = string
}

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

# Attached to Service_B ECS service (allows inbound TCP 5000 from VPC Lattice)
variable "service_b_security_group_id" {
  description = "Security group ID for Service_B from Phase 1 (Lattice inbound on 5000)"
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

# Task role for Service_A - has vpc-lattice-svcs:Invoke permission
variable "service_a_task_role_arn" {
  description = "Service_A task role ARN from Phase 1 (authorized to invoke Lattice)"
  type        = string
}

# Task role for Service_B - no Lattice permissions (it receives requests, doesn't make them)
variable "service_b_task_role_arn" {
  description = "Service_B task role ARN from Phase 1 (no Lattice permissions)"
  type        = string
}

# Task role for Service_C - no Lattice permissions (demonstrates auth denial)
variable "service_c_task_role_arn" {
  description = "Service_C task role ARN from Phase 1 (no Invoke permission - expects 403)"
  type        = string
}

# -----------------------------------------------------------------------------
# Container Image URIs - from Phase 2 (docker build + push)
# -----------------------------------------------------------------------------

# Image used by both Service_A and Service_C task definitions (same code, different roles)
variable "caller_image_uri" {
  description = "ECR image URI for the caller container (from Phase 2 docker push)"
  type        = string
}

# Image used by Service_B task definition
variable "service_b_image_uri" {
  description = "ECR image URI for the Service_B container (from Phase 2 docker push)"
  type        = string
}

# Used in the vpc_lattice_configuration block to allow ECS to register task IPs
# as targets in the VPC Lattice target group automatically.
variable "ecs_infrastructure_role_arn" {
  description = "ECS infrastructure role ARN from Phase 1 (for VPC Lattice target registration)"
  type        = string
}
