# Requirements Document

## Introduction

This specification defines the requirements for a hands-on technical lab tutorial that teaches experienced cloud engineers how to implement service-to-service authentication in AWS using VPC Lattice with IAM authorization. The lab deploys a minimal working environment from a clean AWS account/region with no dependency on pre-existing resources and demonstrates both successful and blocked service-to-service communication. The tutorial is comparable in concept to GCP Cloud Run IAM service identity patterns.

## Glossary

- **Tutorial**: The complete step-by-step lab document including prose, code blocks, commands, and expected outputs
- **Lab_Environment**: The full set of AWS resources deployed by the tutorial's Terraform code
- **VPC**: A single Virtual Private Cloud containing all lab resources in one Availability Zone
- **Service_A**: An ECS Fargate service acting as the authorised caller of Service_B
- **Service_B**: An ECS Fargate service acting as the protected target service, accessible only to authorised callers
- **Service_C**: An ECS Fargate service acting as an unauthorised caller, used to demonstrate access denial
- **Service_Network**: The VPC Lattice service network that connects all services
- **Lattice_Service**: The VPC Lattice service fronting Service_B with a listener and routing rules
- **Auth_Policy**: The VPC Lattice auth policy that permits only Service_A's task role to invoke Service_B
- **Task_Role**: An IAM role assigned to an ECS Fargate task, providing service identity
- **Terraform_Code**: The Infrastructure as Code files that deploy the Lab_Environment
- **Tutorial_Reader**: An experienced cloud engineer following the tutorial steps

## Requirements

### Requirement 1: Tutorial Structure and Completeness

**User Story:** As a Tutorial_Reader, I want a complete end-to-end tutorial with clear sections, so that I can follow it without external references.

#### Acceptance Criteria

1. THE Tutorial SHALL contain the following sections in order: Overview, Architecture Diagram, Prerequisites, Step-by-Step Deployment, Testing, Explanation, and Cleanup Instructions
2. WHEN the Tutorial_Reader reaches the Architecture Diagram section, THE Tutorial SHALL display a Mermaid-style diagram showing the VPC, ECS services, VPC Lattice components, and IAM role relationships
3. THE Tutorial SHALL include inline Terraform code blocks for all infrastructure definitions
4. THE Tutorial SHALL include shell commands using AWS CLI or curl for all manual operations
5. THE Tutorial SHALL include expected output text for each validation step
6. THE Tutorial SHALL include troubleshooting tips for common deployment and connectivity issues
7. THE Tutorial SHALL use commands compatible with a git-bash shell environment on Windows
8. THE Tutorial SHALL use `python` instead of `python3` in all commands

### Requirement 2: Prerequisites and Starting State

**User Story:** As a Tutorial_Reader, I want clear prerequisites listed, so that I know exactly what I need before starting.

#### Acceptance Criteria

1. THE Tutorial SHALL specify that the lab starts from a clean AWS account/region with no dependency on pre-existing resources
2. THE Tutorial SHALL list all required CLI tools: Terraform, AWS CLI, Docker, and curl
3. THE Tutorial SHALL specify the minimum AWS IAM permissions needed to deploy the Lab_Environment
4. THE Tutorial SHALL specify the required Terraform version and AWS provider version

### Requirement 3: Network Infrastructure

**User Story:** As a Tutorial_Reader, I want a minimal VPC setup, so that I can focus on VPC Lattice concepts without network complexity.

#### Acceptance Criteria

1. THE Terraform_Code SHALL deploy exactly one VPC with a CIDR block sufficient for the lab
2. THE Terraform_Code SHALL deploy public subnets in a single Availability Zone
3. THE Terraform_Code SHALL NOT deploy a NAT Gateway in the baseline lab
4. THE Terraform_Code SHALL assign public IP addresses to ECS Fargate tasks to enable image pulls and outbound connectivity
5. THE Terraform_Code SHALL configure security groups to allow outbound internet access but no inbound internet access
6. THE Tutorial SHALL explain that public subnets with public IPs are chosen purely to minimise cost in a learning environment
7. THE Tutorial SHALL describe VPC endpoints for ECR, CloudWatch Logs, and other supporting AWS service access as an OPTIONAL extension for private networking, not part of the baseline deployment

### Requirement 4: ECS Fargate Services

**User Story:** As a Tutorial_Reader, I want minimal ECS services deployed, so that I can observe service-to-service communication with the smallest possible footprint.

#### Acceptance Criteria

1. THE Terraform_Code SHALL deploy three ECS Fargate services: Service_A, Service_B, and Service_C
2. THE Terraform_Code SHALL use the smallest available Fargate task size (0.25 vCPU, 0.5 GB memory) for all services
3. THE Terraform_Code SHALL assign a unique Task_Role to each ECS service
4. WHEN Service_B receives an HTTP request, THE Service_B container SHALL return a simple JSON success response (e.g. message and timestamp) without implementing any authentication or caller validation logic
5. THE Service_B container SHALL NOT inspect or enforce caller identity; unauthorised requests are blocked by VPC Lattice before reaching Service_B
6. WHEN Service_A starts, THE Service_A container SHALL send an HTTP request to Service_B through the Lattice_Service endpoint and print the response
7. WHEN Service_C starts, THE Service_C container SHALL send an HTTP request to Service_B through the Lattice_Service endpoint and print the response
8. THE container images SHALL use a lightweight framework (Python Flask or Node Express) with fewer than 50 lines of application code per service

### Requirement 5: VPC Lattice Configuration

**User Story:** As a Tutorial_Reader, I want to understand VPC Lattice setup, so that I can replicate service mesh patterns in my own projects.

#### Acceptance Criteria

1. THE Terraform_Code SHALL create one Service_Network
2. THE Terraform_Code SHALL create one Lattice_Service associated with Service_B
3. THE Terraform_Code SHALL create an HTTP listener on the Lattice_Service that routes requests to Service_B's target group
4. THE Terraform_Code SHALL associate the VPC with the Service_Network
5. THE Terraform_Code SHALL enable IAM authorization on the Lattice_Service

### Requirement 6: IAM Authorization Policy

**User Story:** As a Tutorial_Reader, I want to see how IAM roles map to service identity and how VPC Lattice enforces authorization, so that I understand the security model.

#### Acceptance Criteria

1. THE Terraform_Code SHALL create an Auth_Policy on the Lattice_Service that permits invocation only from Service_A's Task_Role ARN
2. THE Auth_Policy SHALL deny all principals not explicitly listed
3. THE Terraform_Code SHALL attach an identity-based IAM policy to Service_A's Task_Role that allows the action `vpc-lattice-svcs:Invoke`
4. THE Terraform_Code SHALL NOT attach a `vpc-lattice-svcs:Invoke` permission to Service_C's Task_Role in the baseline deployment
5. WHEN Service_A calls Service_B, THE Lattice_Service SHALL allow the request because BOTH Service_A's identity-based policy allows invocation AND the Auth_Policy permits Service_A's Task_Role
6. WHEN Service_C calls Service_B in the baseline deployment, THE Lattice_Service SHALL deny the request because Service_C lacks caller-side `vpc-lattice-svcs:Invoke` permission and is not permitted by the Auth_Policy
7. THE Tutorial SHALL explain that authorization succeeds only when BOTH the caller's IAM identity-based policy allows `vpc-lattice-svcs:Invoke` AND the VPC Lattice Auth_Policy permits the caller principal
8. THE Tutorial SHALL explain that authorization is enforced by VPC Lattice before the request reaches the service, not by application logic in Service_B

### Requirement 7: SigV4 Request Signing

**User Story:** As a Tutorial_Reader, I want to understand how callers authenticate to VPC Lattice, so that I can implement signed requests in my own services.

#### Acceptance Criteria

1. THE Service_A container SHALL sign HTTP requests to the Lattice_Service using AWS SigV4 with the service name `vpc-lattice-svcs`
2. THE Service_C container SHALL sign HTTP requests to the Lattice_Service using AWS SigV4 with the service name `vpc-lattice-svcs`
3. THE signed requests SHALL include the header `x-amz-content-sha256: UNSIGNED-PAYLOAD`
4. THE container code SHALL use the AWS SDK or a supported signing library (e.g. botocore, requests-aws4auth) for SigV4 signing and SHALL NOT implement SigV4 manually
5. THE Tutorial SHALL explain that SigV4 signing provides the caller identity that VPC Lattice evaluates against the Auth_Policy

### Requirement 8: Testing and Validation

**User Story:** As a Tutorial_Reader, I want clear test steps with expected outputs, so that I can verify the lab works correctly.

#### Acceptance Criteria

1. THE Tutorial SHALL include a test step that shows Service_A successfully receiving a response from Service_B
2. THE Tutorial SHALL include a test step that shows Service_C receiving an access denied error from VPC Lattice
3. THE Tutorial SHALL show the exact expected output or error message for each test case
4. THE Tutorial SHALL provide commands to view ECS task logs to verify request outcomes
5. WHEN the Tutorial_Reader runs the test steps, THE Tutorial SHALL indicate how to distinguish a VPC Lattice auth denial from a network connectivity failure
6. THE Tutorial SHALL include an OPTIONAL experiment where Service_C's Task_Role is granted the `vpc-lattice-svcs:Invoke` permission while remaining denied by the Auth_Policy, demonstrating that the Lattice auth policy still blocks access even when the caller's identity-based policy permits invocation

### Requirement 9: Explanation Section

**User Story:** As a Tutorial_Reader, I want a conceptual explanation of the security model, so that I can apply these patterns beyond the lab.

#### Acceptance Criteria

1. THE Tutorial SHALL explain how ECS Task_Roles map to service identity in VPC Lattice
2. THE Tutorial SHALL explain how VPC Lattice evaluates the Auth_Policy against the caller's IAM principal
3. THE Tutorial SHALL explicitly state that authorization succeeds only when BOTH the caller's identity-based IAM policy allows `vpc-lattice-svcs:Invoke` AND the VPC Lattice Auth_Policy permits the caller principal
4. THE Tutorial SHALL include a brief comparison to GCP Cloud Run IAM service-to-service authentication
5. THE Tutorial SHALL suggest extensions for the lab including JWT-based auth, mTLS options, and private networking with VPC endpoints

### Requirement 10: Cost Minimisation

**User Story:** As a Tutorial_Reader, I want to know the cost of running this lab, so that I can budget appropriately and clean up promptly.

#### Acceptance Criteria

1. THE Tutorial SHALL provide an estimated cost breakdown for 1-2 hours of lab usage
2. THE cost estimate SHALL include line items for: Fargate tasks, VPC Lattice service, and VPC Lattice data processing
3. THE Terraform_Code SHALL use the smallest Fargate task sizes to minimise compute cost
4. THE Tutorial SHALL include a Cleanup section with a single `terraform destroy` command and verification steps to confirm all resources are removed

### Requirement 11: Code Minimalism and Readability

**User Story:** As a Tutorial_Reader, I want minimal readable code, so that I can understand every line without distraction.

#### Acceptance Criteria

1. THE Terraform_Code SHALL contain only resources required for the lab objective
2. THE Terraform_Code SHALL not include production-level complexity such as multi-AZ deployment, auto-scaling, or custom domain names
3. THE Terraform_Code SHALL not include AWS services unrelated to the lab objective
4. THE Terraform_Code SHALL include inline comments explaining the purpose of each resource block
5. THE container application code SHALL be fewer than 50 lines per service

### Requirement 12: Deployment Steps

**User Story:** As a Tutorial_Reader, I want step-by-step deployment instructions, so that I can deploy the lab without guessing.

#### Acceptance Criteria

1. THE Tutorial SHALL provide deployment in three phases: Phase 1 (base infrastructure: VPC, IAM roles, ECR repositories), Phase 2 (build and push container images to ECR), Phase 3 (deploy ECS services, VPC Lattice service network, Lattice service, listener, and Auth_Policy)
2. THE Tutorial SHALL explain how image URIs from Phase 2 are passed into Phase 3 Terraform deployment.
3. THE Tutorial SHALL include the exact Terraform commands to run: `terraform init`, `terraform plan`, and `terraform apply`
4. THE Tutorial SHALL include commands to build and push Docker images to ECR
5. WHEN a deployment step fails, THE Tutorial SHALL provide at least one troubleshooting tip for the most common failure mode of that step
