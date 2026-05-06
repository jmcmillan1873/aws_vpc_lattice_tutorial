# =============================================================================
# Phase 1: Base Infrastructure - Provider and VPC Resources
# =============================================================================
# This file configures the AWS provider and creates the foundational network
# resources for the VPC Lattice service-to-service auth lab.
# =============================================================================

# -----------------------------------------------------------------------------
# Terraform and Provider Configuration
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS provider using the region variable.
# All resources in this phase will be created in this region.
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
# The VPC provides an isolated network for all lab resources.
# CIDR 10.0.0.0/16 gives us plenty of address space for the lab.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Public Subnet
# -----------------------------------------------------------------------------
# A single public subnet in one AZ keeps costs minimal.
# ECS Fargate tasks will receive public IPs here for outbound internet access
# (image pulls, CloudWatch Logs) without needing a NAT Gateway.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-public-subnet"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
# The IGW enables internet connectivity for resources in the public subnet.
# This is required for ECS tasks to pull container images from ECR and send
# logs to CloudWatch without a NAT Gateway (cost optimisation for the lab).
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

# -----------------------------------------------------------------------------
# Route Table
# -----------------------------------------------------------------------------
# Routes all internet-bound traffic (0.0.0.0/0) through the Internet Gateway.
# This makes the subnet "public" - tasks with public IPs can reach the internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route: send all non-local traffic to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.prefix}-public-rt"
  }
}

# -----------------------------------------------------------------------------
# Route Table Association
# -----------------------------------------------------------------------------
# Associates the public route table with our subnet so that instances and
# Fargate tasks in this subnet use the IGW route for outbound traffic.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
