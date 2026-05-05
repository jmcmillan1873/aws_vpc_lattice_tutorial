# Implementation Plan: VPC Lattice Service-to-Service Auth Lab

## Overview

This plan implements a hands-on tutorial teaching VPC Lattice service-to-service authentication with IAM authorization. The implementation follows a 3-phase deployment model: Phase 1 (base infrastructure), Phase 2 (container images), Phase 3 (ECS services + VPC Lattice). All infrastructure is Terraform, all application code is Python, and the final deliverable is a tutorial README.md.

## Tasks

- [ ] 1. Phase 1 — Base Infrastructure Terraform
  - [-] 1.1 Create Phase 1 provider and VPC resources (`lab/phase1/main.tf`)
    - Configure AWS provider with region variable
    - Create VPC (10.0.0.0/16), public subnet (10.0.1.0/24, single AZ), Internet Gateway, route table with 0.0.0.0/0 → IGW
    - Include inline comments explaining each resource
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 11.4_

  - [~] 1.2 Create IAM roles and policies (`lab/phase1/iam.tf`)
    - Create shared task execution role (ECR pull + CloudWatch Logs)
    - Create Task Role A (`service-a-task-role`) with `vpc-lattice-svcs:Invoke` identity policy (Resource: `*`)
    - Create Task Role B (`service-b-task-role`) with no Lattice permissions
    - Create Task Role C (`service-c-task-role`) with no Lattice permissions
    - All task roles use `ecs-tasks.amazonaws.com` trust policy
    - Include production warning comment about scoping Resource to specific Lattice service ARN
    - _Requirements: 6.1, 6.3, 6.4_

  - [~] 1.3 Create ECR repositories (`lab/phase1/ecr.tf`)
    - Create `lab/caller` repository (shared image for Service_A and Service_C)
    - Create `lab/service-b` repository
    - Mutable tags, no lifecycle policy
    - _Requirements: 11.1_

  - [~] 1.4 Create security groups (`lab/phase1/security.tf`)
    - Create `callers` security group: egress all, no ingress
    - Create `service-b` security group: egress all, ingress TCP 5000 from AWS-managed VPC Lattice prefix list (looked up via data source)
    - _Requirements: 3.5_

  - [~] 1.5 Create Phase 1 outputs and variables (`lab/phase1/outputs.tf`, `lab/phase1/variables.tf`)
    - Output: VPC ID, subnet ID, security group IDs, IAM role ARNs, ECR repository URLs, CloudWatch log group names
    - Variables: AWS region, naming prefix
    - _Requirements: 12.1_

- [~] 2. Checkpoint — Phase 1 validation
  - Ensure `terraform validate` passes for `lab/phase1/`
  - Ensure all files have inline comments explaining resource purpose
  - Ask the user if questions arise.

- [ ] 3. Phase 2 — Container Application Code
  - [~] 3.1 Create Service_B Flask application (`lab/services/service_b/`)
    - `app.py`: Flask app, GET `/` returns `{"message": "Hello from Service_B!", "timestamp": "<ISO8601>"}`, listens on port 5000, under 50 lines
    - `Dockerfile`: Lightweight Python base image, install deps, copy app, expose 5000, CMD to run Flask
    - `requirements.txt`: flask
    - _Requirements: 4.4, 4.5, 4.8, 11.5_

  - [~] 3.2 Create shared caller script (`lab/services/caller/`)
    - `caller.py`: Python script using botocore for SigV4 signing and requests for HTTP call. Reads `LATTICE_ENDPOINT` and `AWS_DEFAULT_REGION` from environment. Signs GET request with service name `vpc-lattice-svcs`, includes `x-amz-content-sha256: UNSIGNED-PAYLOAD` header. Prints response status and body. Under 50 lines.
    - `Dockerfile`: Lightweight Python base image, install deps, copy script, CMD to run `python caller.py`
    - `requirements.txt`: botocore, requests
    - _Requirements: 4.6, 4.7, 7.1, 7.2, 7.3, 7.4, 11.5_

- [~] 4. Checkpoint — Container code validation
  - Ensure caller.py and app.py are each under 50 lines
  - Ensure Dockerfiles are correct and minimal
  - Ask the user if questions arise.

- [ ] 5. Phase 3 — ECS Services and VPC Lattice Terraform
  - [~] 5.1 Create Phase 3 provider and data sources (`lab/phase3/main.tf`, `lab/phase3/variables.tf`)
    - Configure AWS provider
    - Define variables for image URIs and Phase 1 outputs (subnet ID, SG IDs, role ARNs, VPC ID)
    - _Requirements: 12.2_

  - [~] 5.2 Create ECS cluster, task definitions, and Service_B ECS service (`lab/phase3/ecs.tf`)
    - Create ECS cluster (Fargate-only)
    - Create CloudWatch log groups for each service (`/ecs/service-a`, `/ecs/service-b`, `/ecs/service-c`)
    - Task Definition A: 0.25 vCPU, 0.5 GB, awsvpc, Task Role A, caller image, container name `caller`
    - Task Definition B: 0.25 vCPU, 0.5 GB, awsvpc, Task Role B, service-b image, container port 5000
    - Task Definition C: 0.25 vCPU, 0.5 GB, awsvpc, Task Role C, caller image, container name `caller`
    - ECS Service for Service_B: desired_count=1, public IP, LATEST platform, associated with Lattice target group
    - _Requirements: 4.1, 4.2, 4.3, 10.3_

  - [~] 5.3 Create VPC Lattice resources (`lab/phase3/lattice.tf`)
    - Create Service Network
    - Create VPC-to-Service-Network association
    - Create Lattice Service with auth type `AWS_IAM`
    - Create IP target group (HTTP, port 5000, health check on `/`)
    - Create HTTP listener (port 80, default forward to target group)
    - Associate ECS Service_B with target group for auto-registration
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [~] 5.4 Create VPC Lattice auth policy (`lab/phase3/auth_policy.tf`)
    - Auth policy on Lattice Service permitting only Service_A's Task Role ARN
    - Implicit deny for all other principals
    - _Requirements: 6.1, 6.2_

  - [~] 5.5 Create Phase 3 outputs (`lab/phase3/outputs.tf`)
    - Output: Lattice service DNS endpoint, ECS cluster name, task definition ARNs, subnet ID, security group ID (for run-task commands)
    - _Requirements: 12.2_

- [~] 6. Checkpoint — Phase 3 validation
  - Ensure `terraform validate` passes for `lab/phase3/`
  - Ensure all Lattice, ECS, and auth policy resources are correctly wired
  - Ask the user if questions arise.

- [ ] 7. Tutorial README
  - [~] 7.1 Create tutorial document (`lab/README.md`) — Sections: Overview through Architecture
    - Write Overview section explaining the lab objective and dual authorization model
    - Write Architecture Diagram section with Mermaid diagrams showing VPC, ECS services, VPC Lattice components, and IAM role relationships
    - Write Prerequisites section: clean AWS account, CLI tools (Terraform, AWS CLI, Docker, curl), minimum IAM permissions, Terraform/provider versions
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 2.3, 2.4_

  - [~] 7.2 Extend tutorial — Step-by-Step Deployment section
    - Phase 1 instructions: `terraform init`, `terraform plan`, `terraform apply` with expected outputs
    - Phase 2 instructions: ECR login, `docker build`, `docker tag`, `docker push` for both images
    - Phase 3 instructions: pass image URIs as variables, `terraform init`, `terraform plan`, `terraform apply`
    - Include troubleshooting tips for common failures at each phase (ECR auth, image not found, subnet routing)
    - All commands compatible with git-bash on Windows; use `python` not `python3`
    - _Requirements: 1.3, 1.4, 1.7, 1.8, 12.1, 12.2, 12.3, 12.4, 12.5_

  - [~] 7.3 Extend tutorial — Testing and Validation section
    - Test 1: Run Service_A via `aws ecs run-task` with container overrides for LATTICE_ENDPOINT and AWS_DEFAULT_REGION, show expected 200 response in logs
    - Test 2: Run Service_C via `aws ecs run-task`, show expected 403 AccessDeniedException in logs
    - Include `aws logs tail` commands to view results
    - Explain how to distinguish auth denial (fast 403) from network failure (timeout)
    - Include optional experiment: grant Service_C Invoke permission, show Lattice policy still blocks
    - _Requirements: 1.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [~] 7.4 Extend tutorial — Explanation, Cost, and Cleanup sections
    - Explanation section: ECS Task Roles as service identity, dual authorization model, comparison to GCP Cloud Run IAM, suggested extensions (JWT, mTLS, VPC endpoints)
    - Cost section: estimated breakdown for 1-2 hours (Fargate, Lattice service, data processing)
    - Cleanup section: `terraform destroy` for Phase 3 then Phase 1, verification steps
    - Note about public subnets being for cost minimisation only, VPC endpoints as optional extension
    - _Requirements: 1.6, 3.6, 3.7, 6.7, 6.8, 7.5, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.4_

- [~] 8. Final checkpoint — Full review
  - Ensure all Terraform files pass `terraform validate`
  - Ensure README covers all 12 requirements
  - Ensure container code is under 50 lines per service
  - Ensure all commands use `python` (not `python3`) and are git-bash compatible
  - Ask the user if questions arise.

## Notes

- No property-based tests are included as this is an IaC/tutorial project without algorithmic correctness properties
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation between deployment phases
- Service_A and Service_C share the same Docker image (`lab/caller`); the difference is purely IAM
- Phase 2 is manual (docker build/push) — no Terraform for this phase
- The tutorial README is the primary deliverable; Terraform and container code support it
