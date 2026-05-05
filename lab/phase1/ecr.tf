# =============================================================================
# Phase 1: ECR Repositories
# =============================================================================
# Creates the two ECR repositories needed for the lab container images.
# These repositories must exist before Phase 2 (docker build/push) can run.
# =============================================================================

# -----------------------------------------------------------------------------
# ECR Repository: lab/caller
# -----------------------------------------------------------------------------
# Stores the caller image shared by both Service_A and Service_C.
# Service_A and Service_C use identical application code — the difference
# between them is purely IAM (Task Role A vs Task Role C), not the image.
resource "aws_ecr_repository" "caller" {
  name                 = "${var.prefix}/caller"
  image_tag_mutability = "MUTABLE" # Allows re-pushing the same tag (e.g. "latest") during the lab

  tags = {
    Name = "${var.prefix}-caller"
  }
}

# -----------------------------------------------------------------------------
# ECR Repository: lab/service-b
# -----------------------------------------------------------------------------
# Stores the Service_B Flask application image.
# This is the protected target service that sits behind VPC Lattice.
resource "aws_ecr_repository" "service_b" {
  name                 = "${var.prefix}/service-b"
  image_tag_mutability = "MUTABLE" # Allows re-pushing the same tag (e.g. "latest") during the lab

  tags = {
    Name = "${var.prefix}-service-b"
  }
}
