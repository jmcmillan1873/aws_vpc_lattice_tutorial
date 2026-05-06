# =============================================================================
# Phase 1: IAM Roles and Policies
# =============================================================================
# This file creates the IAM roles used by ECS Fargate tasks:
# - A shared Task Execution Role (for ECS agent operations: ECR pull, logs)
# - Three Task Roles (one per service) providing unique service identity
#
# In the JWT lab, authorization is enforced by the application (token
# validation), not by IAM. Task roles exist for structural parity with the
# VPC Lattice lab and to give each service a unique IAM identity — but they
# have NO special permissions (no vpc-lattice-svcs:Invoke, no Lattice infra).
# =============================================================================

# -----------------------------------------------------------------------------
# Shared Task Execution Role
# -----------------------------------------------------------------------------
# The execution role is used by the ECS agent (not the application container).
# It needs permissions to pull images from ECR and write logs to CloudWatch.
# All three services share this role since they have identical agent needs.

# Trust policy: allow ECS tasks service to assume this role
data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# The shared execution role itself
resource "aws_iam_role" "task_execution" {
  name               = "${var.prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-task-execution-role"
  }
}

# Attach the AWS-managed policy that grants ECR pull + CloudWatch Logs permissions
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# Task Role A - Service_A (Authorised Caller)
# -----------------------------------------------------------------------------
# This role is assumed by Service_A's container at runtime.
# In the JWT lab, Service_A does NOT need vpc-lattice-svcs:Invoke permission
# because auth is enforced by the application (JWT validation), not by IAM.
# The role exists for structural parity with the VPC Lattice lab.

resource "aws_iam_role" "service_a_task" {
  name               = "${var.prefix}-service-a-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-a-task-role"
  }
}

# -----------------------------------------------------------------------------
# Task Role B - Service_B (Protected Target)
# -----------------------------------------------------------------------------
# This role is assumed by Service_B's container at runtime.
# Service_B validates JWTs at the application layer - no IAM permissions needed.
# The role exists to give Service_B a unique identity within the ECS task.

resource "aws_iam_role" "service_b_task" {
  name               = "${var.prefix}-service-b-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-b-task-role"
  }
}

# -----------------------------------------------------------------------------
# Task Role C - Service_C (Unauthorised Caller)
# -----------------------------------------------------------------------------
# This role is assumed by Service_C's container at runtime.
# In the JWT lab, Service_C is denied by the application (its JWT subject
# "service-c" is not in Service_B's allowed subjects list), not by IAM.
# The role exists for structural parity with the VPC Lattice lab.

resource "aws_iam_role" "service_c_task" {
  name               = "${var.prefix}-service-c-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-c-task-role"
  }
}
