# =============================================================================
# Phase 3: Outputs
# =============================================================================
# These outputs provide the values needed to run the testing phase commands
# (aws ecs run-task) from the tutorial README. They are used as arguments and
# container overrides when launching Service_A and Service_C one-off tasks.
#
# Unlike the VPC Lattice lab, there is no lattice_service_dns output. Instead,
# callers connect directly to Service_B's task IP. The IP must be obtained from
# the running task after deployment (see instructions below).
# =============================================================================

# -----------------------------------------------------------------------------
# ECS Cluster Name - used in aws ecs run-task --cluster argument
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name for run-task commands"
  value       = aws_ecs_cluster.main.name
}

# -----------------------------------------------------------------------------
# Task Definition ARNs - used in aws ecs run-task --task-definition argument
# -----------------------------------------------------------------------------

# Task definition for Service_A (authorised caller - expects 200 response)
output "service_a_task_definition_arn" {
  description = "Task definition ARN for Service_A (authorised caller)"
  value       = aws_ecs_task_definition.service_a.arn
}

# Task definition for Service_C (unauthorised caller - expects 403 response)
output "service_c_task_definition_arn" {
  description = "Task definition ARN for Service_C (unauthorised caller)"
  value       = aws_ecs_task_definition.service_c.arn
}

# -----------------------------------------------------------------------------
# Network Configuration - used in run-task --network-configuration argument
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

# -----------------------------------------------------------------------------
# Service_B Task IP - instructions for obtaining the target URL
# -----------------------------------------------------------------------------
# Service_B's task IP is dynamic and assigned at runtime. After terraform apply,
# use the following commands to obtain it:
#
#   # 1. Get the task ARN
#   TASK_ARN=$(aws ecs list-tasks --cluster jwt-lab-cluster \
#     --service-name service-b --query 'taskArns[0]' --output text)
#
#   # 2. Get the task's public IP
#   SERVICE_B_IP=$(aws ecs describe-tasks --cluster jwt-lab-cluster \
#     --tasks $TASK_ARN \
#     --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
#     --output text | xargs -I {} aws ec2 describe-network-interfaces \
#     --network-interface-ids {} \
#     --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
#
#   # 3. Use as SERVICE_B_URL in run-task overrides
#   echo "http://${SERVICE_B_IP}:5000"
# -----------------------------------------------------------------------------

output "service_b_ip_instructions" {
  description = "Instructions to obtain Service_B task IP for use as SERVICE_B_URL"
  value       = <<-EOT
    After apply, get Service_B's IP with:

    TASK_ARN=$(aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name service-b --query 'taskArns[0]' --output text)

    SERVICE_B_IP=$(aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

    Then use: http://$SERVICE_B_IP:5000 as SERVICE_B_URL in run-task overrides.
  EOT
}
