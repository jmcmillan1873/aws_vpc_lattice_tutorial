# =============================================================================
# Phase 1: IAM Roles and Policies
# =============================================================================
# This file creates the IAM roles used by ECS Fargate tasks:
# - A shared Task Execution Role (for ECS agent operations: ECR pull, logs)
# - Three Task Roles (one per service) providing unique service identity
#
# The key teaching point: Service_A's task role has vpc-lattice-svcs:Invoke
# permission, while Service_B and Service_C do not. Combined with the VPC
# Lattice auth policy (Phase 3), this demonstrates dual authorization.
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
# Task Role A — Service_A (Authorised Caller)
# -----------------------------------------------------------------------------
# This role is assumed by Service_A's container at runtime.
# It includes an identity-based policy allowing vpc-lattice-svcs:Invoke,
# which is one half of the dual authorization model.

resource "aws_iam_role" "service_a_task" {
  name               = "${var.prefix}-service-a-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-a-task-role"
  }
}

# Identity-based policy: allows Service_A to invoke VPC Lattice services
# ⚠️ Production warning: Resource: '*' is used here for lab simplicity only.
# In production, scope this to the specific VPC Lattice service ARN:
# arn:aws:vpc-lattice:<region>:<account>:service/<service-id>
resource "aws_iam_role_policy" "service_a_lattice_invoke" {
  name = "${var.prefix}-service-a-lattice-invoke"
  role = aws_iam_role.service_a_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "vpc-lattice-svcs:Invoke"
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Task Role B — Service_B (Protected Target)
# -----------------------------------------------------------------------------
# This role is assumed by Service_B's container at runtime.
# Service_B does not call VPC Lattice — it only receives requests — so it
# needs no Lattice permissions. The role exists to give Service_B a unique
# identity within the ECS task.

resource "aws_iam_role" "service_b_task" {
  name               = "${var.prefix}-service-b-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-b-task-role"
  }
}

# -----------------------------------------------------------------------------
# Task Role C — Service_C (Unauthorised Caller)
# -----------------------------------------------------------------------------
# This role is assumed by Service_C's container at runtime.
# Service_C intentionally has NO vpc-lattice-svcs:Invoke permission.
# This demonstrates that without the identity-based policy, the request
# is denied — even before the Lattice auth policy is evaluated.

resource "aws_iam_role" "service_c_task" {
  name               = "${var.prefix}-service-c-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.prefix}-service-c-task-role"
  }
}
