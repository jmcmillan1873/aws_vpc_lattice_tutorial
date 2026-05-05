# =============================================================================
# Phase 3: VPC Lattice Resources
# =============================================================================
# This file creates the VPC Lattice service mesh layer:
# - A Service Network that groups services together
# - A VPC association so tasks in the VPC can reach Lattice services
# - A Lattice Service fronting Service_B with IAM authorization enabled
# - A target group pointing to Service_B tasks on port 5000
# - An HTTP listener routing all requests to the target group
# - A service-to-network association linking the service into the network
#
# The ECS Service for Service_B (in ecs.tf) registers its task IPs into the
# target group automatically via the load_balancer block.
# =============================================================================

# -----------------------------------------------------------------------------
# Service Network - logical grouping of Lattice services
# -----------------------------------------------------------------------------
# The service network acts as a boundary within which services can discover
# and communicate with each other. VPCs must be associated with the network
# to enable connectivity.

resource "aws_vpclattice_service_network" "main" {
  name = "${var.prefix}-service-network"
}

# -----------------------------------------------------------------------------
# VPC Association - connects our VPC to the Service Network
# -----------------------------------------------------------------------------
# This association allows ECS tasks running in the VPC to route traffic to
# Lattice services within the service network. Without this, tasks cannot
# resolve or reach Lattice service DNS names.

resource "aws_vpclattice_service_network_vpc_association" "main" {
  vpc_identifier             = var.vpc_id
  service_network_identifier = aws_vpclattice_service_network.main.id
}

# -----------------------------------------------------------------------------
# Lattice Service - fronts Service_B with IAM authorization
# -----------------------------------------------------------------------------
# The Lattice service is the entry point for callers wanting to reach Service_B.
# Setting auth_type to AWS_IAM means every request must be SigV4-signed and
# will be evaluated against both the caller's identity policy and the Lattice
# auth policy (defined in auth_policy.tf).

resource "aws_vpclattice_service" "service_b" {
  name      = "${var.prefix}-service-b"
  auth_type = "AWS_IAM"
}

# -----------------------------------------------------------------------------
# Service Network ↔ Service Association
# -----------------------------------------------------------------------------
# Links the Lattice service into the service network so it becomes reachable
# by any VPC associated with that network. This is required for end-to-end
# connectivity between callers and the service.

resource "aws_vpclattice_service_network_service_association" "service_b" {
  service_identifier         = aws_vpclattice_service.service_b.id
  service_network_identifier = aws_vpclattice_service_network.main.id
}

# -----------------------------------------------------------------------------
# Target Group - routes traffic to Service_B task IPs on port 5000
# -----------------------------------------------------------------------------
# Type "IP" is required for VPC Lattice target groups. The ECS service
# automatically registers and deregisters task IPs as targets when tasks
# start or stop (via the vpc_lattice_configuration block in ecs.tf).
# Health checks on "/" ensure only healthy tasks receive traffic.

resource "aws_vpclattice_target_group" "service_b" {
  name = "${var.prefix}-service-b-tg"
  type = "IP"

  config {
    port             = 5000
    protocol         = "HTTP"
    vpc_identifier   = var.vpc_id

    health_check {
      enabled                       = true
      path                          = "/"
      protocol                      = "HTTP"
      healthy_threshold_count       = 2
      unhealthy_threshold_count     = 2
      health_check_timeout_seconds  = 5
      health_check_interval_seconds = 30
    }
  }
}

# -----------------------------------------------------------------------------
# HTTP Listener - accepts requests on port 80 and forwards to target group
# -----------------------------------------------------------------------------
# The listener defines how the Lattice service receives inbound requests.
# All traffic on port 80 is forwarded to the Service_B target group.
# Callers use the Lattice service DNS name on port 80 to reach Service_B.

resource "aws_vpclattice_listener" "service_b" {
  name               = "${var.prefix}-service-b-listener"
  service_identifier = aws_vpclattice_service.service_b.id
  protocol           = "HTTP"
  port               = 80

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.service_b.id
        weight                  = 100
      }
    }
  }
}
