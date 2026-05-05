# =============================================================================
# Phase 3: VPC Lattice Auth Policy
# =============================================================================
# This file defines the resource-based authorization policy attached to the
# VPC Lattice service fronting Service_B.
#
# VPC Lattice uses a DUAL AUTHORIZATION MODEL:
#   1. The caller's identity-based IAM policy must allow vpc-lattice-svcs:Invoke
#      (defined in Phase 1 on Service_A's task role)
#   2. This resource-based auth policy must also permit the caller's principal
#
# A request is forwarded to Service_B ONLY when both checks pass.
# Any principal not explicitly listed here is implicitly denied — no explicit
# Deny statement is needed because the default evaluation is deny.
#
# In this lab:
#   - Service_A (Task Role A) → allowed by BOTH policies → 200 OK
#   - Service_C (Task Role C) → denied by BOTH policies  → 403 AccessDeniedException
# =============================================================================

resource "aws_vpclattice_auth_policy" "service_b" {
  # Attach this policy to the Lattice service that fronts Service_B.
  # The service has auth_type = "AWS_IAM" (set in lattice.tf), which means
  # every inbound request is evaluated against this policy.
  resource_identifier = aws_vpclattice_service.service_b.arn

  # The policy permits ONLY Service_A's task role to invoke the service.
  # All other principals receive an implicit deny — VPC Lattice will return
  # HTTP 403 AccessDeniedException before the request ever reaches Service_B.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # Only Service_A's ECS task role is authorized to call this service.
          # This ARN is passed in from Phase 1 outputs via the variable.
          AWS = var.service_a_task_role_arn
        }
        # The vpc-lattice-svcs:Invoke action is the only action evaluated
        # by VPC Lattice auth policies.
        Action   = "vpc-lattice-svcs:Invoke"
        Resource = "*"
      }
    ]
  })
}
