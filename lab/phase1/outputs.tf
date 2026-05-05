# =============================================================================
# Phase 1: Outputs
# =============================================================================
# These outputs expose resource identifiers needed by Phase 3 Terraform
# configuration and by the tutorial's manual steps (e.g., run-task commands).
# =============================================================================

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

# Used by Phase 3 to associate the VPC with the Lattice Service Network
output "vpc_id" {
  description = "ID of the lab VPC"
  value       = aws_vpc.main.id
}

# Used by Phase 3 for ECS task networking (awsvpcConfiguration) and run-task commands
output "subnet_id" {
  description = "ID of the public subnet where ECS tasks are launched"
  value       = aws_subnet.public.id
}

# -----------------------------------------------------------------------------
# Security Group Outputs
# -----------------------------------------------------------------------------

# Used by Phase 3 for Service_A and Service_C task networking (egress-only callers)
output "callers_security_group_id" {
  description = "Security group ID for caller tasks (Service_A, Service_C)"
  value       = aws_security_group.callers.id
}

# Used by Phase 3 for Service_B ECS service networking (allows Lattice inbound on 5000)
output "service_b_security_group_id" {
  description = "Security group ID for Service_B (inbound from VPC Lattice)"
  value       = aws_security_group.service_b.id
}

# -----------------------------------------------------------------------------
# IAM Role Outputs
# -----------------------------------------------------------------------------

# Used by Phase 3 in all task definitions for ECS agent operations (ECR pull, logs)
output "task_execution_role_arn" {
  description = "ARN of the shared task execution role (ECR pull + CloudWatch Logs)"
  value       = aws_iam_role.task_execution.arn
}

# Used by Phase 3 in Service_A task definition and by the Lattice auth policy
output "service_a_task_role_arn" {
  description = "ARN of Service_A task role (has vpc-lattice-svcs:Invoke permission)"
  value       = aws_iam_role.service_a_task.arn
}

# Used by Phase 3 in Service_B task definition
output "service_b_task_role_arn" {
  description = "ARN of Service_B task role (no Lattice permissions)"
  value       = aws_iam_role.service_b_task.arn
}

# Used by Phase 3 in Service_C task definition
output "service_c_task_role_arn" {
  description = "ARN of Service_C task role (no Lattice permissions — demonstrates denial)"
  value       = aws_iam_role.service_c_task.arn
}

# -----------------------------------------------------------------------------
# ECR Repository Outputs
# -----------------------------------------------------------------------------

# Used in Phase 2 docker push commands and Phase 3 task definition image references
output "caller_ecr_repository_url" {
  description = "ECR repository URL for the caller image (shared by Service_A and Service_C)"
  value       = aws_ecr_repository.caller.repository_url
}

# Used in Phase 2 docker push commands and Phase 3 task definition image references
output "service_b_ecr_repository_url" {
  description = "ECR repository URL for the Service_B image"
  value       = aws_ecr_repository.service_b.repository_url
}
