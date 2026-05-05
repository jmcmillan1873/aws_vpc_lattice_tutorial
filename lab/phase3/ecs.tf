# =============================================================================
# Phase 3: ECS Cluster, Task Definitions, and Service_B ECS Service
# =============================================================================
# This file creates the ECS compute layer for the lab:
# - A Fargate-only ECS cluster
# - CloudWatch log groups for each service's container logs
# - Three task definitions (Service_A, Service_B, Service_C)
# - An ECS Service for Service_B (long-running, fronted by VPC Lattice)
#
# Service_A and Service_C are one-off tasks launched via `aws ecs run-task`
# during the testing phase. Only Service_B runs as a persistent ECS Service
# because it must be available to receive requests and pass health checks.
# =============================================================================

# -----------------------------------------------------------------------------
# ECS Cluster - Fargate-only, no capacity providers needed
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups - one per service for isolated log streams
# -----------------------------------------------------------------------------

# Log group for Service_A (authorised caller) task output
resource "aws_cloudwatch_log_group" "service_a" {
  name              = "/ecs/service-a"
  retention_in_days = 7
}

# Log group for Service_B (protected target) task output
resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/service-b"
  retention_in_days = 7
}

# Log group for Service_C (unauthorised caller) task output
resource "aws_cloudwatch_log_group" "service_c" {
  name              = "/ecs/service-c"
  retention_in_days = 7
}

# -----------------------------------------------------------------------------
# Task Definition A - Authorised caller (uses caller image with Task Role A)
# -----------------------------------------------------------------------------
# Service_A uses the shared caller image and Task Role A which has
# vpc-lattice-svcs:Invoke permission. This task is run as a one-off via
# `aws ecs run-task` with container overrides for LATTICE_ENDPOINT.

resource "aws_ecs_task_definition" "service_a" {
  family                   = "service-a"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU - smallest Fargate size
  memory                   = "512" # 0.5 GB - smallest Fargate size
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.service_a_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "caller"
      image     = var.caller_image_uri
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_a.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# Task Definition B - Protected target service (Flask app on port 5000)
# -----------------------------------------------------------------------------
# Service_B runs as a long-running ECS Service. It listens on port 5000 and
# returns a JSON response. VPC Lattice routes traffic to it via the target group.

resource "aws_ecs_task_definition" "service_b" {
  family                   = "service-b"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU - smallest Fargate size
  memory                   = "512" # 0.5 GB - smallest Fargate size
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.service_b_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "service-b"
      image     = var.service_b_image_uri
      essential = true
      portMappings = [
        {
          name          = "service-b-http"
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_b.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# Task Definition C - Unauthorised caller (same caller image, Task Role C)
# -----------------------------------------------------------------------------
# Service_C uses the same caller image as Service_A but with Task Role C which
# lacks vpc-lattice-svcs:Invoke permission. Demonstrates auth denial (403).

resource "aws_ecs_task_definition" "service_c" {
  family                   = "service-c"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU - smallest Fargate size
  memory                   = "512" # 0.5 GB - smallest Fargate size
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.service_c_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "caller"
      image     = var.caller_image_uri
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service_c.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# ECS Service for Service_B - long-running service fronted by VPC Lattice
# -----------------------------------------------------------------------------
# Service_B must run continuously to receive requests routed through VPC Lattice.
# The load_balancer block associates it with the Lattice target group so ECS
# automatically registers/deregisters task IPs as targets.

resource "aws_ecs_service" "service_b" {
  name             = "service-b"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.service_b.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # Network configuration - public IP for outbound connectivity (image pulls, logs)
  network_configuration {
    subnets          = [var.subnet_id]
    security_groups  = [var.service_b_security_group_id]
    assign_public_ip = true
  }

  # Native ECS + VPC Lattice integration. ECS uses the infrastructure role to
  # automatically register and deregister task IPs in the Lattice target group
  # as tasks start and stop. port_name must match the portMapping name in the
  # task definition above.
  vpc_lattice_configurations {
    role_arn         = var.ecs_infrastructure_role_arn
    target_group_arn = aws_vpclattice_target_group.service_b.arn
    port_name        = "service-b-http"
  }
}
