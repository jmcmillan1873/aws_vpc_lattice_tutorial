# =============================================================================
# Phase 3: ECS Cluster, Task Definitions, and Service_B ECS Service
# =============================================================================
# This file creates the ECS compute layer for the JWT auth lab:
# - A Fargate-only ECS cluster
# - CloudWatch log groups for each service's container logs
# - Three task definitions (Service_A, Service_B, Service_C)
# - An ECS Service for Service_B (long-running, receives direct HTTP requests)
#
# Service_A and Service_C are one-off tasks launched via `aws ecs run-task`
# during the testing phase. Only Service_B runs as a persistent ECS Service
# because it must be available to receive requests from callers.
#
# Key difference from VPC Lattice lab: No vpc_lattice_configurations block,
# no infrastructure role, no target group. Callers connect directly to
# Service_B's task IP on port 5000.
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
  name              = "/ecs/jwt-service-a"
  retention_in_days = 7
}

# Log group for Service_B (protected target) task output
resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/jwt-service-b"
  retention_in_days = 7
}

# Log group for Service_C (unauthorised caller) task output
resource "aws_cloudwatch_log_group" "service_c" {
  name              = "/ecs/jwt-service-c"
  retention_in_days = 7
}

# -----------------------------------------------------------------------------
# Task Definition A - Authorised caller (uses caller image with Task Role A)
# -----------------------------------------------------------------------------
# Service_A uses the shared caller image and Task Role A. It generates a JWT
# with sub=service-a and sends it to Service_B. This task is run as a one-off
# via `aws ecs run-task` with container overrides for SERVICE_B_URL.

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
      environment = [
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "CALLER_SUBJECT"
          value = "service-a"
        }
      ]
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
# Service_B runs as a long-running ECS Service. It listens on port 5000,
# validates incoming JWTs, and returns success or denial responses.
# Auth is enforced by the application: it checks the JWT signature, issuer,
# audience, expiry, and subject against the allowed subjects list.

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
      environment = [
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "ALLOWED_SUBJECTS"
          value = "service-a"
        },
        {
          name  = "EXPECTED_ISSUER"
          value = "mock-idp"
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
# Service_C uses the same caller image as Service_A but with CALLER_SUBJECT
# set to "service-c". This subject is NOT in Service_B's ALLOWED_SUBJECTS list,
# so the request will be rejected with HTTP 403 — demonstrating that a valid
# token (correct signature) does not imply authorization.

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
      environment = [
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "CALLER_SUBJECT"
          value = "service-c"
        }
      ]
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
# ECS Service for Service_B - long-running service receiving direct HTTP calls
# -----------------------------------------------------------------------------
# Service_B must run continuously to receive requests from caller tasks.
# Unlike the VPC Lattice lab, there is no target group or Lattice integration.
# Callers connect directly to Service_B's task IP on port 5000.

resource "aws_ecs_service" "service_b" {
  name             = "service-b"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.service_b.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # Network configuration - public IP for outbound connectivity (image pulls, logs)
  # and for callers to reach Service_B directly on port 5000
  network_configuration {
    subnets          = [var.subnet_id]
    security_groups  = [var.service_b_security_group_id]
    assign_public_ip = true
  }
}
