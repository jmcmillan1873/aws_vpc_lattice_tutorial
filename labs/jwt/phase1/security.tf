# =============================================================================
# Phase 1: Security Groups
# =============================================================================
# Two security groups control network access for ECS tasks:
#   1. "callers" - used by Service_A and Service_C (outbound only)
#   2. "service-b" - used by Service_B (inbound TCP 5000 from callers SG)
#
# Unlike the VPC Lattice lab, there is no prefix list reference here.
# Service_B allows inbound directly from the callers security group because
# callers communicate with Service_B over the VPC network (no Lattice proxy).
# No security group permits inbound traffic from 0.0.0.0/0.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group: Callers (Service_A and Service_C)
# -----------------------------------------------------------------------------
# Allows all outbound traffic (needed for HTTP requests to Service_B,
# image pulls from ECR, and log delivery to CloudWatch).
# No inbound rules - callers do not receive any incoming connections.
resource "aws_security_group" "callers" {
  name        = "${var.prefix}-callers-sg"
  description = "Security group for caller tasks (Service_A, Service_C) - egress only"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (required for HTTP calls, ECR pulls, CW Logs)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No ingress rules - callers never receive inbound connections

  tags = {
    Name = "${var.prefix}-callers-sg"
  }
}

# -----------------------------------------------------------------------------
# Security Group: Service_B
# -----------------------------------------------------------------------------
# Allows all outbound traffic (image pulls, log delivery) and inbound TCP 5000
# from the callers security group.
#
# In the JWT lab, callers connect directly to Service_B's task IP on port 5000.
# There is no VPC Lattice proxy in between, so the security group references
# the callers SG directly (not a prefix list).
# This is the ONLY inbound rule in the entire lab - no 0.0.0.0/0 ingress.
resource "aws_security_group" "service_b" {
  name        = "${var.prefix}-service-b-sg"
  description = "Security group for Service_B - allows inbound from callers on port 5000"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (required for ECR pulls, CW Logs)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound TCP 5000 from the callers security group.
  # This permits Service_A and Service_C to send HTTP requests directly
  # to Service_B's Flask container on port 5000.
  ingress {
    description     = "Allow inbound HTTP from caller tasks"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.callers.id]
  }

  tags = {
    Name = "${var.prefix}-service-b-sg"
  }
}
