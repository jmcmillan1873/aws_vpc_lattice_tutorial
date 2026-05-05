# =============================================================================
# Phase 1: Input Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for all lab resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Naming prefix for all resources (keeps names unique and identifiable)"
  type        = string
  default     = "lab"
}
