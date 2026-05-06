# Requirements Document

## Introduction

This specification defines the requirements for a parallel implementation of the existing VPC Lattice service-to-service authentication lab. The JWT lab replicates the same observable behaviour (Service_A allowed, Service_C denied) but replaces VPC Lattice infrastructure-enforced auth with application-layer JWT/OIDC validation. Both labs coexist in the same repository for direct comparison of infrastructure-enforced vs application-enforced auth patterns.

The JWT lab uses a mock identity provider with a shared signing key — no Cognito, no external IdPs, no OAuth flows. The focus is on the auth pattern itself, not on building an auth system.

## Glossary

- **JWT_Lab**: The complete set of code and infrastructure at `lab-jwt/` implementing application-layer JWT auth
- **VPC_Lattice_Lab**: The existing lab at `lab/` implementing infrastructure-layer auth via VPC Lattice
- **Service_A**: An ECS Fargate task acting as the authorised caller; generates a valid JWT and calls Service_B
- **Service_B**: An ECS Fargate service acting as the protected target; validates JWTs and allows or denies requests
- **Service_C**: An ECS Fargate task acting as the unauthorised caller; generates a valid JWT with an unauthorised subject and calls Service_B
- **JWT**: A JSON Web Token containing issuer, subject, audience, and expiry claims
- **Signing_Key**: A shared HMAC secret used to sign and verify JWTs across all services. This is a lab simplification - in production, services do not share signing keys (see Requirement 7)
- **Token_Validator**: The middleware in Service_B that validates JWT signature, claims, and expiry
- **Token_Issuer**: (Optional extension only) A lightweight mock service that owns the Signing_Key and issues JWTs to callers on request
- **Terraform_Code**: The Infrastructure as Code files that deploy the JWT_Lab environment
- **Tutorial_Reader**: An experienced cloud engineer following the tutorial steps

## Requirements

### Requirement 1: Parallel Lab Structure

**User Story:** As a Tutorial_Reader, I want the JWT lab to exist alongside the VPC Lattice lab, so that I can compare both approaches in the same repository.

#### Acceptance Criteria

1. THE JWT_Lab SHALL be located at `lab-jwt/` in the repository root, parallel to the existing `lab/` directory
2. THE JWT_Lab SHALL NOT modify, remove, or depend on any files in the existing `lab/` directory
3. THE JWT_Lab SHALL mirror the existing lab structure with phases: `lab-jwt/phase1/` (VPC, IAM, ECR, security groups), `lab-jwt/phase3/` (ECS services), and `lab-jwt/services/` (application code)
4. THE JWT_Lab SHALL preserve the same VPC design as the VPC_Lattice_Lab: single VPC, public subnet, single AZ, no NAT Gateway, public IPs on Fargate tasks
5. THE JWT_Lab SHALL preserve the same ECS Fargate setup: 0.25 vCPU, 0.5 GB memory, `awsvpc` network mode
6. THE JWT_Lab SHALL preserve the same three-service role structure: Service_A (authorised caller), Service_B (protected target), Service_C (unauthorised caller)

### Requirement 2: Remove VPC Lattice Components

**User Story:** As a Tutorial_Reader, I want the JWT lab to have no VPC Lattice dependencies, so that I can see a pure application-layer auth implementation.

#### Acceptance Criteria

1. THE Terraform_Code SHALL NOT create any VPC Lattice resources: no service network, no Lattice service, no listener, no target group, no auth policy, no VPC association
2. THE Terraform_Code SHALL NOT create an ECS Infrastructure Role for VPC Lattice target registration
3. THE Terraform_Code SHALL NOT attach `vpc-lattice-svcs:Invoke` permissions to any Task Role
4. THE Terraform_Code SHALL NOT reference the AWS-managed VPC Lattice prefix list in any security group rule
5. WHEN Service_A or Service_C calls Service_B, THE request SHALL be routed directly via Service_B's private IP or service discovery DNS, not through any VPC Lattice endpoint

### Requirement 3: JWT Token Structure

**User Story:** As a Tutorial_Reader, I want a clearly defined JWT structure, so that I can understand what claims are used for authorization decisions.

#### Acceptance Criteria

1. THE JWT SHALL include the following registered claims: `iss` (issuer), `sub` (subject), `aud` (audience), and `exp` (expiry)
2. THE `iss` claim SHALL identify the mock identity provider (e.g. `mock-idp`)
3. THE `sub` claim SHALL identify the calling service (e.g. `service-a` or `service-c`)
4. THE `aud` claim SHALL identify the target service (e.g. `service-b`)
5. THE `exp` claim SHALL be set to a future timestamp providing a reasonable validity window
6. THE JWT SHALL be signed using HMAC-SHA256 (HS256) with a shared Signing_Key
7. THE Signing_Key SHALL be passed to all services via environment variable

### Requirement 4: Service_A Behaviour (Authorised Caller)

**User Story:** As a Tutorial_Reader, I want Service_A to demonstrate a successful JWT-authenticated call, so that I can see the positive auth flow.

#### Acceptance Criteria

1. WHEN Service_A starts, THE Service_A container SHALL generate a JWT with `sub` set to `service-a` and `aud` set to `service-b`
2. THE Service_A container SHALL sign the JWT using the shared Signing_Key with HS256 algorithm
3. THE Service_A container SHALL send an HTTP request to Service_B with the JWT in the `Authorization: Bearer <token>` header
4. THE Service_A container SHALL use an HTTP request timeout of 5 seconds
5. THE Service_A container SHALL log the HTTP response status code and body to stdout
6. WHEN Service_B returns HTTP 200, THE Service_A log output SHALL clearly indicate the request was accepted
7. WHEN the HTTP request fails due to timeout or connection error, THE Service_A log output SHALL clearly indicate a network failure (distinct from an auth failure)
8. THE Service_A application code SHALL be fewer than 50 lines

### Requirement 5: Service_B Behaviour (Protected Target)

**User Story:** As a Tutorial_Reader, I want Service_B to validate JWTs and enforce authorization, so that I can see application-layer auth in action.

#### Acceptance Criteria

1. THE Service_B container SHALL require a JWT in the `Authorization: Bearer <token>` header on all requests
2. WHEN a request arrives without an Authorization header, THE Token_Validator SHALL return HTTP 401 with a JSON body indicating the reason
3. WHEN a request arrives with an invalid JWT signature, THE Token_Validator SHALL return HTTP 401 with a JSON body indicating signature verification failed
4. WHEN a request arrives with an expired JWT, THE Token_Validator SHALL return HTTP 401 with a JSON body indicating the token is expired
5. WHEN a request arrives with a JWT where the `aud` claim does not match `service-b`, THE Token_Validator SHALL return HTTP 403 with a JSON body indicating invalid audience
6. WHEN a request arrives with a JWT where the `sub` claim is not in the allowed subjects list, THE Token_Validator SHALL return HTTP 403 with a JSON body indicating unauthorised subject
7. WHEN a request arrives with a valid JWT (correct signature, non-expired, correct audience, allowed subject), THE Service_B container SHALL return HTTP 200 with a JSON success response including a message and timestamp
8. THE Service_B container SHALL log each request outcome including the subject claim and the accept/reject decision with reason
9. THE Service_B application code SHALL be fewer than 50 lines
10. THE allowed subjects list SHALL be configurable via environment variable
11. WHEN a request arrives with a JWT where the `iss` claim does not match the expected issuer, THE Token_Validator SHALL return HTTP 401 with a JSON body indicating invalid issuer
12. THE expected issuer SHALL be configurable via environment variable
13. THE Token_Validator SHALL explicitly require the HS256 algorithm and reject tokens using any other algorithm

### Requirement 6: Service_C Behaviour (Unauthorised Caller)

**User Story:** As a Tutorial_Reader, I want Service_C to demonstrate that a valid identity does not imply authorisation, so that I can see the difference between authentication and authorization.

#### Acceptance Criteria

1. WHEN Service_C starts, THE Service_C container SHALL generate a valid, correctly-signed JWT with `sub` set to `service-c` and `aud` set to `service-b`
2. THE Service_C container SHALL sign the JWT using the same shared Signing_Key and HS256 algorithm as Service_A
3. THE Service_C container SHALL send an HTTP request to Service_B with the JWT in the `Authorization: Bearer <token>` header
4. THE Service_C container SHALL use an HTTP request timeout of 5 seconds
5. THE Service_C container SHALL log the HTTP response status code and body to stdout
6. WHEN Service_B returns HTTP 403, THE Service_C log output SHALL clearly indicate the request was rejected due to unauthorised subject
7. WHEN the HTTP request fails due to timeout or connection error, THE Service_C log output SHALL clearly indicate a network failure (distinct from an auth failure)
8. THE Service_C application code SHALL be fewer than 50 lines
9. THE JWT generated by Service_C SHALL be structurally valid (correct signature, non-expired, correct audience) - the ONLY reason for rejection SHALL be that `service-c` is not in Service_B's allowed subjects list

### Requirement 7: Token Issuance Simplicity

**User Story:** As a Tutorial_Reader, I want token generation to be trivially simple, so that I can focus on the auth validation pattern rather than token infrastructure.

#### Acceptance Criteria

1. THE JWT_Lab SHALL NOT use AWS Cognito, Auth0, Keycloak, or any external identity provider
2. THE JWT_Lab SHALL NOT implement OAuth 2.0 flows (authorization code, client credentials, or implicit)
3. THE JWT_Lab SHALL NOT deploy a separate token-issuing service or endpoint in the baseline implementation
4. THE Service_A and Service_C containers SHALL generate their own JWTs using the shared Signing_Key directly
5. THE token generation code SHALL use the `pyjwt` library and require no more than 5 lines of code per service
6. THE Tutorial SHALL explicitly document that the shared signing key model is a lab simplification only
7. THE Tutorial SHALL explain that in production: (a) services do NOT share signing keys, (b) tokens are issued by a trusted identity provider, (c) services cannot mint their own identity tokens, and (d) the signing key is held only by the issuer while services hold only the verification key

### Requirement 8: Minimal Dependencies

**User Story:** As a Tutorial_Reader, I want minimal Python dependencies, so that the containers are lightweight and the code is easy to understand.

#### Acceptance Criteria

1. THE Service_B container SHALL depend only on: `flask` and `pyjwt`
2. THE Service_A and Service_C containers SHALL depend only on: `requests` and `pyjwt`
3. THE container images SHALL NOT include `botocore`, `boto3`, or any AWS SDK libraries
4. THE container images SHALL use a standard Python base image

### Requirement 9: Infrastructure Configuration

**User Story:** As a Tutorial_Reader, I want the infrastructure to be as simple as the VPC Lattice lab minus the Lattice components, so that I can focus on the application-layer auth difference.

#### Acceptance Criteria

1. THE Terraform_Code SHALL deploy a single VPC with a public subnet in one Availability Zone
2. THE Terraform_Code SHALL deploy an Internet Gateway with a route table for outbound connectivity
3. THE Terraform_Code SHALL deploy a shared ECS Task Execution Role for ECR pulls and CloudWatch Logs
4. THE Terraform_Code SHALL deploy three unique Task Roles (one per service) even though JWT auth does not depend on IAM identity — to maintain structural parity with the VPC_Lattice_Lab
5. THE Terraform_Code SHALL deploy ECR repositories for the service container images
6. THE Terraform_Code SHALL deploy CloudWatch Log Groups for each service
7. THE Terraform_Code SHALL deploy security groups that allow Service_A and Service_C to reach Service_B on its container port
8. THE Terraform_Code SHALL deploy an ECS Cluster with Fargate launch type
9. THE Terraform_Code SHALL pass the Signing_Key to containers via ECS task definition environment variables

### Requirement 10: Service Discovery

**User Story:** As a Tutorial_Reader, I want Service_A and Service_C to discover Service_B's address simply, so that I can focus on the auth pattern rather than service discovery.

#### Acceptance Criteria

1. THE JWT_Lab SHALL use a `SERVICE_B_URL` environment variable to provide Service_B's address to caller tasks
2. THE `SERVICE_B_URL` SHALL be passed at runtime via ECS `run-task` container overrides (same pattern as the VPC_Lattice_Lab uses for `LATTICE_ENDPOINT`)
3. THE JWT_Lab SHALL NOT introduce AWS Cloud Map, ECS Service Connect, or any additional service discovery infrastructure
4. THE Tutorial SHALL document how to obtain Service_B's task IP or DNS and pass it as `SERVICE_B_URL`

### Requirement 11: Testing and Validation

**User Story:** As a Tutorial_Reader, I want clear test steps showing Service_A succeeds and Service_C fails, so that I can verify the JWT auth pattern works correctly.

#### Acceptance Criteria

1. THE Tutorial SHALL include a test step showing Service_A receiving HTTP 200 from Service_B
2. THE Tutorial SHALL include a test step showing Service_C receiving HTTP 401 or 403 from Service_B
3. THE Tutorial SHALL show expected log output for both successful and denied requests
4. THE Tutorial SHALL provide commands to view ECS task logs to verify request outcomes
5. THE log output SHALL clearly distinguish between: token accepted (with subject), token rejected due to invalid signature, token rejected due to wrong audience, token rejected due to unauthorised subject, and token rejected due to expiry
6. WHEN the Tutorial_Reader runs the test steps, THE Tutorial SHALL indicate how to distinguish a JWT auth denial from a network connectivity failure

### Requirement 12: Explanation and Comparison Section

**User Story:** As a Tutorial_Reader, I want a comparison between VPC Lattice auth and JWT auth, so that I can understand when to use each approach and how the concepts map between them.

#### Acceptance Criteria

1. THE Tutorial SHALL include an explanation section comparing VPC Lattice (infrastructure-enforced) auth with JWT (application-enforced) auth
2. THE explanation SHALL include a concept alignment table mapping: Identity (IAM Role ↔ JWT sub), Enforcement point (before service ↔ inside service), Auth decision (IAM + Auth Policy ↔ token validation + subject check)
3. THE explanation SHALL cover the following trade-off dimensions: portability across cloud providers, cost implications, operational complexity, security boundary differences, and failure modes
4. THE explanation SHALL state that VPC Lattice auth is enforced before requests reach the application while JWT auth is enforced by the application itself
5. THE explanation SHALL emphasise that both approaches implement the same concept (identity-based access control) at different layers
6. THE explanation SHALL state that JWT auth is portable across any environment (cloud, on-premises, local development) while VPC Lattice is AWS-specific
7. THE explanation SHALL state that VPC Lattice auth requires no application code changes while JWT auth requires each service to implement token validation
8. THE explanation SHALL state that JWT auth introduces key management responsibility (rotation, distribution, revocation) that VPC Lattice avoids by delegating to IAM
9. THE explanation SHALL note that VPC Lattice incurs per-hour and per-GB charges while JWT auth has no direct service cost beyond compute
10. THE explanation SHALL include a TLS security note stating: JWT over HTTP is acceptable for this lab only; in production, JWTs MUST be transmitted over HTTPS, otherwise tokens can be intercepted and replayed by any network observer
11. THE explanation SHALL NOT introduce TLS into the lab implementation - the note is informational only

### Requirement 13: Code Minimalism and Readability

**User Story:** As a Tutorial_Reader, I want minimal readable code, so that I can understand every line without distraction.

#### Acceptance Criteria

1. THE application code for each service SHALL be fewer than 50 lines
2. THE Terraform_Code SHALL contain only resources required for the JWT_Lab objective
3. THE Terraform_Code SHALL include inline comments explaining the purpose of each resource block
4. THE Terraform_Code SHALL NOT include production-level complexity such as multi-AZ deployment, auto-scaling, or custom domain names
5. THE container code SHALL include comments explaining the JWT generation and validation logic

### Requirement 14: Deployment Steps

**User Story:** As a Tutorial_Reader, I want step-by-step deployment instructions, so that I can deploy the JWT lab without guessing.

#### Acceptance Criteria

1. THE Tutorial SHALL provide deployment in phases matching the VPC_Lattice_Lab: Phase 1 (base infrastructure), image build/push, Phase 3 (ECS services)
2. THE Tutorial SHALL include the exact Terraform commands: `terraform init`, `terraform plan`, and `terraform apply`
3. THE Tutorial SHALL include commands to build and push Docker images to ECR
4. THE Tutorial SHALL explain how Service_B's address is obtained and passed to caller tasks
5. THE Tutorial SHALL use commands compatible with a git-bash shell environment
6. THE Tutorial SHALL use `python` instead of `python3` in all commands

### Requirement 15: Cost Minimisation

**User Story:** As a Tutorial_Reader, I want to know the cost of running the JWT lab, so that I can compare it to the VPC Lattice lab cost.

#### Acceptance Criteria

1. THE Tutorial SHALL provide an estimated cost breakdown for 1-2 hours of lab usage
2. THE cost estimate SHALL note the absence of VPC Lattice per-hour and data-processing charges compared to the VPC_Lattice_Lab
3. THE Terraform_Code SHALL use the smallest Fargate task sizes to minimise compute cost
4. THE Tutorial SHALL include a Cleanup section with a single `terraform destroy` command and verification steps

### Requirement 16: Optional Extension - More Realistic Token Issuance

**User Story:** As a Tutorial_Reader who has completed the baseline lab, I want an optional extension that introduces a mock token issuer, so that I can see how the pattern evolves toward production-realistic token issuance without the complexity of a real IdP.

#### Acceptance Criteria

1. THE extension SHALL be clearly marked as OPTIONAL and SHALL NOT modify the baseline lab implementation
2. THE extension SHALL introduce a lightweight Token_Issuer service that owns the Signing_Key and exposes a simple `/token` endpoint
3. WHEN Service_A requests a token from Token_Issuer, THE Token_Issuer SHALL return a JWT with `sub` set to `service-a` and `aud` set to `service-b`
4. WHEN Service_C requests a token from Token_Issuer, THE Token_Issuer SHALL return a JWT with `sub` set to `service-c` and `aud` set to `service-b`
5. IN the extension, Service_A and Service_C SHALL NOT hold the Signing_Key directly - they SHALL obtain tokens from the Token_Issuer
6. IN the extension, Service_B SHALL continue to validate tokens using the same Signing_Key (shared with Token_Issuer only, not with callers)
7. THE Token_Issuer application code SHALL be fewer than 50 lines
8. THE extension SHALL NOT introduce Cognito, OAuth flows, JWKS endpoints, external identity providers, or certificate management
9. THE Tutorial SHALL explain why this model is more realistic: callers no longer hold signing keys, identity is issued by a central authority
10. THE Tutorial SHALL explain how this maps to real-world systems: Cognito, Auth0, workload identity / OIDC providers
11. THE Tutorial SHALL explain why it is still simplified: no trust chain, no key rotation, no token exchange flows, no token revocation
12. THE extension SHALL maintain the same constraints as the baseline: minimal dependencies, under 50 lines per service, no production-level complexity
