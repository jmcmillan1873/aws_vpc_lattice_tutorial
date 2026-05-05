# =============================================================================
# Phase 3: Outputs
# =============================================================================
# These outputs provide the values needed to run the testing phase commands
# (aws ecs run-task) from the tutorial README. They are used as arguments and
# container overrides when launching Service_A and Service_C one-off tasks.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Lattice Service DNS — used as LATTICE_ENDPOINT in container overrides
# -----------------------------------------------------------------------------
# This is the DNS name that caller tasks (Service_A, Service_C) use as the
# target URL for their SigV4-signed HTTP requests. Passed via run-task
# container overrides as the LATTICE_ENDPOINT environment variable.

output "lattice_service_dns" {
  description = "DNS endpoint of the VPC Lattice service fronting Service_B (use as LATTICE_ENDPOINT in run-task overrides)"
  value       = aws_vpclattice_service.service_b.dns_entry[0].domain_name
}

# -----------------------------------------------------------------------------
# ECS Cluster Name — used in aws ecs run-task --cluster argument
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name for run-task commands"
  value       = aws_ecs_cluster.main.name
}

# -----------------------------------------------------------------------------
# Task Definition ARNs — used in aws ecs run-task --task-definition argument
# -----------------------------------------------------------------------------

# Task definition for Service_A (authorised caller — expects 200 response)
output "service_a_task_definition_arn" {
  description = "Task definition ARN for Service_A (authorised caller)"
  value       = aws_ecs_task_definition.service_a.arn
}

# Task definition for Service_C (unauthorised caller — expects 403 response)
output "service_c_task_definition_arn" {
  description = "Task definition ARN for Service_C (unauthorised caller)"
  value       = aws_ecs_task_definition.service_c.arn
}

# -----------------------------------------------------------------------------
# Network Configuration — used in run-task --network-configuration argument
# -----------------------------------------------------------------------------

# Subnet for awsvpcConfiguration in run-task commands
output "subnet_id" {
  description = "Subnet ID for ECS task networking (awsvpcConfiguration in run-task)"
  value       = var.subnet_id
}

# Security group for caller tasks (egress-only) in run-task commands
output "callers_security_group_id" {
  description = "Security group ID for caller tasks (use in run-task awsvpcConfiguration)"
  value       = var.callers_security_group_id
}
