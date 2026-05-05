# =============================================================================
# Phase 1: Security Groups
# =============================================================================
# Two security groups control network access for ECS tasks:
#   1. "callers" - used by Service_A and Service_C (outbound only)
#   2. "service-b" - used by Service_B (inbound from VPC Lattice on port 5000)
#
# No security group permits inbound traffic from 0.0.0.0/0.
# =============================================================================

# -----------------------------------------------------------------------------
# Data Source: AWS-Managed VPC Lattice Prefix List
# -----------------------------------------------------------------------------
# VPC Lattice routes traffic to targets from a set of AWS-managed IP ranges.
# Instead of hardcoding these IPs (which may change), we look up the
# AWS-managed prefix list at deploy time. This ensures the security group
# always references the correct, up-to-date Lattice source addresses.
data "aws_ec2_managed_prefix_list" "vpc_lattice" {
  name = "com.amazonaws.${var.aws_region}.vpc-lattice"
}

# -----------------------------------------------------------------------------
# Security Group: Callers (Service_A and Service_C)
# -----------------------------------------------------------------------------
# Allows all outbound traffic (needed for SigV4-signed requests to Lattice,
# image pulls from ECR, and log delivery to CloudWatch).
# No inbound rules - callers do not receive any incoming connections.
resource "aws_security_group" "callers" {
  name        = "${var.prefix}-callers-sg"
  description = "Security group for caller tasks (Service_A, Service_C) - egress only"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (required for Lattice calls, ECR pulls, CW Logs)
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
# ONLY from the AWS-managed VPC Lattice prefix list.
#
# Why the prefix list? VPC Lattice forwards requests to targets from its own
# managed IP range. By referencing the prefix list rather than a CIDR, we
# ensure the rule stays correct even if AWS updates the Lattice IP ranges.
# This is the ONLY inbound rule in the entire lab - no 0.0.0.0/0 ingress.
resource "aws_security_group" "service_b" {
  name        = "${var.prefix}-service-b-sg"
  description = "Security group for Service_B - allows inbound from VPC Lattice only"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (required for ECR pulls, CW Logs)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound TCP 5000 from VPC Lattice prefix list only.
  # This permits Lattice to forward HTTP requests to the Flask container.
  ingress {
    description     = "Allow inbound HTTP from VPC Lattice"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.vpc_lattice.id]
  }

  tags = {
    Name = "${var.prefix}-service-b-sg"
  }
}
