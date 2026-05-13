# =============================================================================
# Phase 1: ECR Repositories
# =============================================================================
# Creates the two ECR repositories needed for the lab container images.
# These repositories must exist before Phase 2 (docker build/push) can run.
# =============================================================================

# -----------------------------------------------------------------------------
# ECR Repository: jwt-lab/caller
# -----------------------------------------------------------------------------
# Stores the caller image shared by both Service_A and Service_C.
# Service_A and Service_C use identical application code - the difference
# between them is the CALLER_SUBJECT environment variable (service-a vs
# service-c), which determines the JWT subject claim.
resource "aws_ecr_repository" "caller" {
  name                 = "${var.prefix}/caller"
  image_tag_mutability = "MUTABLE" # Allows re-pushing the same tag (e.g. "latest") during the lab
  force_delete         = true      # Allows terraform destroy to remove the repo even if it contains images

  tags = {
    Name = "${var.prefix}-caller"
  }
}

# -----------------------------------------------------------------------------
# ECR Repository: jwt-lab/service-b
# -----------------------------------------------------------------------------
# Stores the Service_B Flask application image.
# This is the protected target service that validates JWTs at the application layer.
resource "aws_ecr_repository" "service_b" {
  name                 = "${var.prefix}/service-b"
  image_tag_mutability = "MUTABLE" # Allows re-pushing the same tag (e.g. "latest") during the lab
  force_delete         = true      # Allows terraform destroy to remove the repo even if it contains images

  tags = {
    Name = "${var.prefix}-service-b"
  }
}
