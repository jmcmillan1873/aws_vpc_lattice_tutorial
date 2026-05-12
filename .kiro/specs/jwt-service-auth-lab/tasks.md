# Tasks

## Task 1: Create lab-jwt directory structure and Phase 1 Terraform (VPC, IAM, ECR, Security Groups)

- [x] 1.1 Create `lab-jwt/phase1/main.tf` with provider config, VPC, public subnet, IGW, route table (mirror existing lab/phase1/main.tf but with `jwt-lab` prefix)
- [x] 1.2 Create `lab-jwt/phase1/iam.tf` with shared task execution role and three task roles (no Lattice permissions — roles exist for structural parity only)
- [x] 1.3 Create `lab-jwt/phase1/ecr.tf` with two ECR repositories: `jwt-lab/caller` and `jwt-lab/service-b`
- [x] 1.4 Create `lab-jwt/phase1/security.tf` with two security groups: callers (egress-only) and service-b (ingress TCP 5000 from callers SG)
- [x] 1.5 Create `lab-jwt/phase1/outputs.tf` exporting subnet ID, security group IDs, role ARNs, ECR repository URLs
- [x] 1.6 Create `lab-jwt/phase1/variables.tf` with region and prefix variables

## Task 2: Create Phase 3 Terraform (ECS Cluster, Task Definitions, Service_B ECS Service)

- [x] 2.1 Create `lab-jwt/phase3/main.tf` with provider config and data sources
- [x] 2.2 Create `lab-jwt/phase3/ecs.tf` with ECS cluster, three CloudWatch log groups, three task definitions (with JWT_SECRET, CALLER_SUBJECT, ALLOWED_SUBJECTS, EXPECTED_ISSUER env vars), and Service_B ECS service
- [x] 2.3 Create `lab-jwt/phase3/outputs.tf` with instructions for obtaining Service_B task IP
- [x] 2.4 Create `lab-jwt/phase3/variables.tf` with image URIs, Phase 1 outputs, and jwt_secret variable

## Task 3: Create Service_B application (Flask + JWT validation)

- [x] 3.1 Create `lab-jwt/services/service_b/app.py` — Flask app with JWT validation middleware (under 50 lines): verify HS256 signature, issuer, audience, expiry, and subject against allowed list
- [x] 3.2 Create `lab-jwt/services/service_b/requirements.txt` with flask and pyjwt dependencies
- [x] 3.3 Create `lab-jwt/services/service_b/Dockerfile` using standard Python base image

## Task 4: Create caller application (shared by Service_A and Service_C)

- [x] 4.1 Create `lab-jwt/services/caller/caller.py` — Python script (under 50 lines): read env vars, generate JWT with configurable subject, send HTTP request with Bearer token, log result with distinct network vs auth error handling
- [x] 4.2 Create `lab-jwt/services/caller/requirements.txt` with requests and pyjwt dependencies
- [x] 4.3 Create `lab-jwt/services/caller/Dockerfile` using standard Python base image

## Task 5: Create property-based tests for JWT validation logic

- [x] 5.1 Create `lab-jwt/tests/requirements.txt` with pytest, hypothesis, flask, and pyjwt
- [x] 5.2 Create `lab-jwt/tests/test_jwt_validation.py` implementing all 9 correctness properties using hypothesis with minimum 100 iterations each
- [x] 5.3 Run property-based tests and verify all pass

## Task 6: Create tutorial README with deployment steps and comparison section

- [x] 6.1 Create `lab-jwt/README.md` with overview, prerequisites, and phased deployment instructions (terraform init/plan/apply, docker build/push, run-task commands)
- [x] 6.2 Add testing section showing expected Service_A (200) and Service_C (403) outcomes with log viewing commands
- [x] 6.3 Add comparison section: VPC Lattice vs JWT auth concept alignment table, trade-off dimensions (portability, cost, complexity, security boundary, failure modes), and TLS security note
- [x] 6.4 Add optional extension section describing Token_Issuer service pattern
- [x] 6.5 Add cleanup section with terraform destroy commands and cost estimate
