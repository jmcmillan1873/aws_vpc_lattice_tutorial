# JWT Service-to-Service Authentication Lab

This lab teaches application-layer service-to-service authentication using JWT (JSON Web Tokens). Three ECS Fargate services demonstrate both successful and blocked inter-service communication — identical observable outcomes to the [VPC Lattice lab](../vpc-lattice/), but with auth enforced by the application rather than infrastructure.

**Time**: 30–45 minutes | **Cost**: < $0.10 | **Prerequisites**: see below

> ⚠️ **Lab simplification**: All services share the same HMAC signing key via environment variable. This allows callers to mint their own tokens — a pattern that would be unacceptable in production. See the [Comparison](#comparison-vpc-lattice-vs-jwt-auth) section for details.

---

## Architecture

```mermaid
graph LR
    subgraph AWS Account
        subgraph VPC["VPC (10.0.0.0/16)"]
            subgraph SN["Public Subnet (AZ-a)"]
                A["Service_A<br/>(Authorised Caller)"]
                B["Service_B<br/>(Protected Target)"]
                C["Service_C<br/>(Unauthorised Caller)"]
            end
        end
    end

    A -->|"HTTP + Bearer JWT<br/>sub=service-a → 200 OK"| B
    C -->|"HTTP + Bearer JWT<br/>sub=service-c → 403"| B
```

**How it works**: Service_A and Service_C both generate valid, correctly-signed JWTs. The only difference is the `sub` (subject) claim. Service_B validates the token and checks whether the subject is in its allowed list. Service_A (`service-a`) is allowed; Service_C (`service-c`) is not.

This demonstrates the **authentication vs authorization distinction**: Service_C proves its identity (valid token) but lacks authorization (subject not permitted).

---

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.14.0 | Infrastructure deployment |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | AWS operations, ECR login, ECS run-task |
| [Docker](https://docs.docker.com/get-docker/) | Latest stable | Build and push container images |
| [Python](https://www.python.org/downloads/) | 3.9+ | Running property-based tests locally (optional) |

You also need an AWS account with permissions for VPC, ECS, IAM, ECR, and CloudWatch Logs. For a learning environment, `AdministratorAccess` avoids permission issues.

---

## Deployment

The lab deploys in three phases:

```mermaid
graph LR
    P1["Phase 1<br/>Base Infrastructure"]
    P2["Phase 2<br/>Container Images"]
    P3["Phase 3<br/>ECS Services"]

    P1 -->|"ECR URLs, subnet ID,<br/>SG IDs, role ARNs"| P2
    P2 -->|"Image URIs"| P3
```

---

### Phase 1: Deploy Base Infrastructure

Phase 1 creates the VPC, subnet, IAM roles, ECR repositories, and security groups.

```bash
cd labs/jwt/phase1
terraform init
terraform plan
terraform apply -auto-approve
```

Expected outputs after apply:

```
caller_ecr_repository_url = "<account_id>.dkr.ecr.us-east-1.amazonaws.com/jwt-lab/caller"
service_b_ecr_repository_url = "<account_id>.dkr.ecr.us-east-1.amazonaws.com/jwt-lab/service-b"
callers_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
service_b_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
subnet_id = "subnet-xxxxxxxxxxxxxxxxx"
task_execution_role_arn = "arn:aws:iam::<account_id>:role/jwt-lab-task-execution-role"
...
```

Capture outputs into shell variables:

```bash
export AWS_REGION="us-east-1"
export CALLER_ECR_URL=$(terraform output -raw caller_ecr_repository_url)
export SERVICE_B_ECR_URL=$(terraform output -raw service_b_ecr_repository_url)
export ACCOUNT_ID=$(echo $CALLER_ECR_URL | cut -d'.' -f1)
```

---

### Phase 2: Build and Push Container Images

Navigate back to the `labs/jwt/` directory:

```bash
cd ..
```

#### Authenticate Docker to ECR

```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

#### Build and push Service_B

```bash
docker build -t jwt-lab/service-b ./services/service_b/
docker tag jwt-lab/service-b:latest $SERVICE_B_ECR_URL:latest
docker push $SERVICE_B_ECR_URL:latest
```

#### Build and push the caller image

This image is shared by both Service_A and Service_C — the difference is the `CALLER_SUBJECT` environment variable set in the task definition.

```bash
docker build -t jwt-lab/caller ./services/caller/
docker tag jwt-lab/caller:latest $CALLER_ECR_URL:latest
docker push $CALLER_ECR_URL:latest
```

---

### Phase 3: Deploy ECS Services

```bash
cd phase3
terraform init

terraform apply -auto-approve \
  -var="subnet_id=$(terraform -chdir=../phase1 output -raw subnet_id)" \
  -var="callers_security_group_id=$(terraform -chdir=../phase1 output -raw callers_security_group_id)" \
  -var="service_b_security_group_id=$(terraform -chdir=../phase1 output -raw service_b_security_group_id)" \
  -var="task_execution_role_arn=$(terraform -chdir=../phase1 output -raw task_execution_role_arn)" \
  -var="service_a_task_role_arn=$(terraform -chdir=../phase1 output -raw service_a_task_role_arn)" \
  -var="service_b_task_role_arn=$(terraform -chdir=../phase1 output -raw service_b_task_role_arn)" \
  -var="service_c_task_role_arn=$(terraform -chdir=../phase1 output -raw service_c_task_role_arn)" \
  -var="caller_image_uri=$CALLER_ECR_URL:latest" \
  -var="service_b_image_uri=$SERVICE_B_ECR_URL:latest" \
  -var="jwt_secret=my-super-secret-key-for-lab"
```

Wait for Service_B to start (1–2 minutes):

```bash
echo "Waiting for Service_B to start..."
sleep 90
aws ecs list-tasks --cluster jwt-lab-cluster --service-name service-b --region $AWS_REGION
```

#### Get Service_B's IP address

Service_B runs as a Fargate task with a public IP. You need this IP to tell callers where to send requests.

```bash
TASK_ARN=$(aws ecs list-tasks --cluster jwt-lab-cluster \
  --service-name service-b --query 'taskArns[0]' --output text --region $AWS_REGION)

ENI_ID=$(aws ecs describe-tasks --cluster jwt-lab-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text --region $AWS_REGION)

SERVICE_B_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text --region $AWS_REGION)

echo "Service_B URL: http://$SERVICE_B_IP:5000"
```

Save this for the testing phase:

```bash
export SERVICE_B_URL="http://$SERVICE_B_IP:5000"
```

---

## Testing

Capture Phase 3 outputs:

```bash
export CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
export SUBNET_ID=$(terraform output -raw subnet_id)
export SG_ID=$(terraform output -raw callers_security_group_id)
```

### Test 1: Service_A → Service_B (Expected: 200 OK)

Service_A generates a JWT with `sub=service-a`, which is in Service_B's allowed subjects list.

```bash
aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition service-a \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"caller\",\"environment\":[{\"name\":\"SERVICE_B_URL\",\"value\":\"$SERVICE_B_URL\"}]}]}" \
  --launch-type FARGATE \
  --platform-version LATEST \
  --region $AWS_REGION
```

Wait and check logs:

```bash
sleep 30
aws logs tail /ecs/jwt-service-a --since 5m --region $AWS_REGION
```

**Expected output:**

```
AUTH SUCCESS: status=200 body={"message": "Hello from Service_B!", "subject": "service-a", "timestamp": "2025-..."}
```

### Test 2: Service_C → Service_B (Expected: 403 Forbidden)

Service_C generates a JWT with `sub=service-c`. The token is valid (correct signature, non-expired, correct audience) but `service-c` is not in Service_B's allowed subjects list.

```bash
aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition service-c \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"caller\",\"environment\":[{\"name\":\"SERVICE_B_URL\",\"value\":\"$SERVICE_B_URL\"}]}]}" \
  --launch-type FARGATE \
  --platform-version LATEST \
  --region $AWS_REGION
```

Wait and check logs:

```bash
sleep 30
aws logs tail /ecs/jwt-service-c --since 5m --region $AWS_REGION
```

**Expected output:**

```
AUTH DENIED: status=403 body={"error": "unauthorised subject", "subject": "service-c"}
```

---

## How It Works

Now that you've seen Service_A succeed and Service_C fail, let's trace exactly why — by following the token through Service_B's validation logic.

### Service_B's Validation Pipeline

Every request to Service_B passes through five checks, in order. A failure at any step short-circuits the rest:

```mermaid
graph TD
    Request["Incoming HTTP request"]
    Check1{"1. Authorization header<br/>present with Bearer token?"}
    Check2{"2. HS256 signature valid<br/>(using JWT_SECRET)?"}
    Check3{"3. iss == mock-idp?"}
    Check4{"4. aud == service-b?"}
    Check5{"5. exp > current time?"}
    Check6{"6. sub in ALLOWED_SUBJECTS?"}
    Success["200 OK ✓"]
    Deny401a["401 - missing authorization header"]
    Deny401b["401 - invalid signature"]
    Deny401c["401 - invalid issuer"]
    Deny403a["403 - invalid audience"]
    Deny401d["401 - token expired"]
    Deny403b["403 - unauthorised subject"]

    Request --> Check1
    Check1 -->|No| Deny401a
    Check1 -->|Yes| Check2
    Check2 -->|No| Deny401b
    Check2 -->|Yes| Check3
    Check3 -->|No| Deny401c
    Check3 -->|Yes| Check4
    Check4 -->|No| Deny403a
    Check4 -->|Yes| Check5
    Check5 -->|No| Deny401d
    Check5 -->|Yes| Check6
    Check6 -->|No| Deny403b
    Check6 -->|Yes| Success
```

### Tracing Service_A (success)

Service_A generates this JWT payload:

```json
{"iss": "mock-idp", "sub": "service-a", "aud": "service-b", "exp": <future>}
```

Walking through the checks:

| Step | Check | Result |
|------|-------|--------|
| 1 | Authorization header present? | ✓ `Bearer <token>` |
| 2 | Signature valid (same JWT_SECRET)? | ✓ Both share the key |
| 3 | `iss` == `mock-idp`? | ✓ Matches EXPECTED_ISSUER |
| 4 | `aud` == `service-b`? | ✓ Correct audience |
| 5 | `exp` > now? | ✓ Token generated with 5-min window |
| 6 | `sub` in ALLOWED_SUBJECTS? | ✓ `service-a` is in `["service-a"]` |

All six checks pass → **200 OK**.

### Tracing Service_C (failure)

Service_C generates this JWT payload:

```json
{"iss": "mock-idp", "sub": "service-c", "aud": "service-b", "exp": <future>}
```

Walking through the same checks:

| Step | Check | Result |
|------|-------|--------|
| 1 | Authorization header present? | ✓ |
| 2 | Signature valid? | ✓ Same shared key |
| 3 | `iss` == `mock-idp`? | ✓ |
| 4 | `aud` == `service-b`? | ✓ |
| 5 | `exp` > now? | ✓ |
| 6 | `sub` in ALLOWED_SUBJECTS? | ✗ `service-c` is NOT in `["service-a"]` |

Service_C passes authentication (steps 1–5 prove it is who it claims to be) but fails authorization (step 6 — it's not permitted). This is the key insight: **a valid identity does not imply access**.

### The difference from VPC Lattice

In the VPC Lattice lab, Service_C fails because:
1. Its IAM role lacks `vpc-lattice-svcs:Invoke` permission (identity policy gate)
2. The Lattice auth policy doesn't list its role ARN (resource policy gate)

In the JWT lab, Service_C fails because:
- Its subject claim (`service-c`) is not in Service_B's allowed subjects list

Both enforce the same concept — identity-based access control — but at different layers. VPC Lattice enforces it in infrastructure before the request reaches the application. JWT enforces it inside the application code.

---

## Knowledge Challenge

You've seen Service_A succeed and Service_C fail. You understand why.

**Challenge: can you update the solution so Service_C is also allowed to call Service_B?**

Think about what you've just traced. There's only one gate that blocked Service_C — and only one place that gate is configured.

Give it a go before reading the hint below.

<details>
<summary><strong>Hint</strong></summary>

The `ALLOWED_SUBJECTS` environment variable in Service_B's task definition controls who gets through step 6. It's currently set to `service-a`.

You have two options:

**Option A — Update via Terraform (persistent)**

Edit `labs/jwt/phase3/ecs.tf` and change the `ALLOWED_SUBJECTS` value in Service_B's container definition:

```hcl
{
  name  = "ALLOWED_SUBJECTS"
  value = "service-a,service-c"
}
```

Then re-apply:

```bash
terraform apply -auto-approve \
  -var="subnet_id=$(terraform -chdir=../phase1 output -raw subnet_id)" \
  -var="callers_security_group_id=$(terraform -chdir=../phase1 output -raw callers_security_group_id)" \
  -var="service_b_security_group_id=$(terraform -chdir=../phase1 output -raw service_b_security_group_id)" \
  -var="task_execution_role_arn=$(terraform -chdir=../phase1 output -raw task_execution_role_arn)" \
  -var="service_a_task_role_arn=$(terraform -chdir=../phase1 output -raw service_a_task_role_arn)" \
  -var="service_b_task_role_arn=$(terraform -chdir=../phase1 output -raw service_b_task_role_arn)" \
  -var="service_c_task_role_arn=$(terraform -chdir=../phase1 output -raw service_c_task_role_arn)" \
  -var="caller_image_uri=$CALLER_ECR_URL:latest" \
  -var="service_b_image_uri=$SERVICE_B_ECR_URL:latest" \
  -var="jwt_secret=my-super-secret-key-for-lab"
```

ECS will deploy a new Service_B task with the updated environment. Wait for it to stabilise, get the new IP, then re-run Service_C.

**Option B — Quick test via ECS Console (temporary)**

Stop the current Service_B task and update the service's task definition to include `service-c` in `ALLOWED_SUBJECTS`. This is faster for experimentation but won't persist if you re-apply Terraform.

**Expected result after the fix:**

```
AUTH SUCCESS: status=200 body={"message": "Hello from Service_B!", "subject": "service-c", "timestamp": "2025-..."}
```

</details>

---

### Distinguishing Auth Failures from Network Errors

If you see `NETWORK ERROR: Connection timed out` or `NETWORK ERROR: Connection refused` instead of `AUTH SUCCESS` or `AUTH DENIED`, the issue is network connectivity — not JWT auth. Check:

1. Service_B task is in RUNNING state
2. The `SERVICE_B_URL` IP is correct (re-run the IP lookup commands above)
3. Security groups allow callers to reach Service_B on port 5000

Auth responses always show `AUTH SUCCESS` or `AUTH DENIED` with an HTTP status code. Network errors always show `NETWORK ERROR` with a connection-level message.

---

## Comparison: VPC Lattice vs JWT Auth

Both labs produce the same observable outcome — Service_A gets through, Service_C is blocked — but they enforce access control at fundamentally different layers.

### Concept Alignment

| Concept | VPC Lattice Lab | JWT Lab |
|---------|----------------|---------|
| **Identity** | IAM Role ARN attached to ECS task | JWT `sub` claim (e.g. `service-a`) |
| **Credential** | AWS SigV4 signature (automatic) | JWT Bearer token (generated in code) |
| **Enforcement point** | VPC Lattice service network (before request reaches app) | Token validation middleware (inside the application) |
| **Auth decision** | IAM identity policy + Lattice resource-based auth policy | Signature verification + subject allowlist check |
| **Policy language** | JSON IAM policy document | Environment variable (`ALLOWED_SUBJECTS`) |
| **Deny behaviour** | HTTP 403 from Lattice (app never sees the request) | HTTP 403 from Flask (app processes and rejects) |

### Trade-off Dimensions

| Dimension | VPC Lattice | JWT (Application-Layer) |
|-----------|-------------|------------------------|
| **Portability** | AWS-only (tied to IAM + Lattice) | Any environment — cloud, on-prem, local dev |
| **Application code changes** | None — auth is invisible to the app | Every service must implement token validation |
| **Key management** | Delegated to IAM (no keys to manage) | You own rotation, distribution, and revocation |
| **Security boundary** | Network layer — requests are blocked before reaching the container | Application layer — malformed requests still hit your code |
| **Cost** | ~$0.025/hr per Lattice service + $0.025/GB data processing | No direct auth cost (compute only) |
| **Failure modes** | IAM propagation delay; Lattice service health | Token expiry clock skew; secret rotation gaps; validation bugs |
| **Observability** | Lattice access logs (automatic) | Application logs (you build it) |
| **Blast radius of a bug** | Auth policy misconfiguration exposes the service | Validation code bug exposes the service |

### The Key Insight

Both approaches implement **identity-based access control**. The difference is where the gate sits:

- **VPC Lattice**: the gate is in the infrastructure. Your application never sees denied requests. You can't accidentally bypass it with a code change.
- **JWT**: the gate is in your code. It's portable and flexible, but every service must implement it correctly, and a bug in validation logic means the gate is open.

Neither is universally better. VPC Lattice is stronger when you want infrastructure-level guarantees and are committed to AWS. JWT is stronger when you need portability, multi-cloud support, or fine-grained claims-based authorization that goes beyond identity.

### TLS Security Note

> ⚠️ **This lab transmits JWTs over plain HTTP.** This is acceptable only because all traffic stays within a single VPC on a private network.
>
> In production, JWTs MUST be transmitted over HTTPS (TLS). Without TLS, any network observer can intercept a token and replay it to impersonate the caller. VPC Lattice avoids this concern entirely — it handles TLS termination and SigV4 verification at the infrastructure layer.
>
> This lab intentionally omits TLS to keep the focus on the auth pattern. Do not replicate this in any environment where traffic crosses a network boundary.

---

## Optional Extension: Token Issuer Service

The baseline lab has a deliberate simplification: every service holds the signing key and mints its own tokens. This is fine for demonstrating the validation pattern, but it means any service can impersonate any other service — there's no central authority controlling identity.

This section describes how you'd evolve the pattern toward production-realistic token issuance without introducing a real identity provider.

### The Pattern

```mermaid
graph LR
    TI["Token_Issuer<br/>(owns signing key)"]
    A["Service_A"]
    B["Service_B"]
    C["Service_C"]

    A -->|"POST /token<br/>client_id=service-a"| TI
    TI -->|"JWT (sub=service-a)"| A
    A -->|"Bearer JWT → 200"| B

    C -->|"POST /token<br/>client_id=service-c"| TI
    TI -->|"JWT (sub=service-c)"| C
    C -->|"Bearer JWT → 403"| B
```

**What changes:**
- A new `Token_Issuer` service holds the signing key exclusively
- Service_A and Service_C request tokens from Token_Issuer instead of generating their own
- Service_B still validates tokens the same way (no change to the validation logic)
- Callers no longer hold the signing key — they can't forge tokens

**What stays the same:**
- Service_B's validation pipeline is identical
- The observable outcome is unchanged (Service_A: 200, Service_C: 403)
- The authorization decision is still based on the `sub` claim

### Why This Is More Realistic

In the baseline lab, the shared signing key means trust is implicit — any service that has the key can claim any identity. With a Token Issuer:

- **Identity is issued, not self-asserted** — callers prove who they are to the issuer, and the issuer vouches for them
- **The signing key has a single owner** — compromise of one caller doesn't compromise the signing key
- **Authorization and authentication are cleanly separated** — the issuer handles "who are you?", Service_B handles "are you allowed?"

### How This Maps to Real-World Systems

| Lab Concept | Production Equivalent |
|-------------|----------------------|
| Token_Issuer service | AWS Cognito, Auth0, Keycloak, Google Workload Identity |
| `POST /token` endpoint | OAuth 2.0 client credentials grant |
| Shared HMAC key | RSA/ECDSA key pair (issuer holds private key, services hold public key or JWKS URL) |
| Hardcoded `sub` claim | Identity derived from mTLS certificate, instance metadata, or service account |

### What's Still Simplified

Even with a Token Issuer, this lab omits production concerns:

- **No trust chain** — the issuer's identity isn't verified by a certificate authority
- **No key rotation** — the signing key is static for the lab's lifetime
- **No token exchange** — services can't delegate identity to downstream calls
- **No token revocation** — issued tokens are valid until they expire
- **No JWKS endpoint** — Service_B uses a shared secret rather than fetching public keys

These are all solvable problems, but each adds complexity that would obscure the core pattern this lab teaches.

### Implementation Sketch

If you want to build this extension yourself, here's the approach:

1. Create `labs/jwt/services/token_issuer/app.py` — a Flask app (~30 lines) with a `POST /token` endpoint that accepts a `client_id` parameter and returns a signed JWT
2. Add a Token_Issuer task definition to Phase 3 with the `JWT_SECRET` env var
3. Remove `JWT_SECRET` from the caller task definitions
4. Add a `TOKEN_ISSUER_URL` env var to the caller task definitions
5. Update `caller.py` to request a token from Token_Issuer before calling Service_B

The Token_Issuer doesn't need to authenticate callers (that would require another auth mechanism — turtles all the way down). It simply maps `client_id` to a `sub` claim. The point is demonstrating centralised issuance, not building a secure IdP.

---

## Cleanup

Destroy resources in reverse order to avoid dependency errors.

### Tear down Phase 3 (ECS services)

```bash
cd labs/jwt/phase3

terraform destroy -auto-approve \
  -var="subnet_id=$(terraform -chdir=../phase1 output -raw subnet_id)" \
  -var="callers_security_group_id=$(terraform -chdir=../phase1 output -raw callers_security_group_id)" \
  -var="service_b_security_group_id=$(terraform -chdir=../phase1 output -raw service_b_security_group_id)" \
  -var="task_execution_role_arn=$(terraform -chdir=../phase1 output -raw task_execution_role_arn)" \
  -var="service_a_task_role_arn=$(terraform -chdir=../phase1 output -raw service_a_task_role_arn)" \
  -var="service_b_task_role_arn=$(terraform -chdir=../phase1 output -raw service_b_task_role_arn)" \
  -var="service_c_task_role_arn=$(terraform -chdir=../phase1 output -raw service_c_task_role_arn)" \
  -var="caller_image_uri=$CALLER_ECR_URL:latest" \
  -var="service_b_image_uri=$SERVICE_B_ECR_URL:latest" \
  -var="jwt_secret=my-super-secret-key-for-lab"
```

### Tear down Phase 1 (base infrastructure)

```bash
cd ../phase1
terraform destroy -auto-approve
```

### Verify cleanup

Confirm no resources remain:

```bash
aws ecs list-clusters --region $AWS_REGION | grep jwt-lab
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*jwt-lab*" --region $AWS_REGION --query 'Vpcs[].VpcId'
```

Both commands should return empty results.

### Cost Estimate

| Resource | Configuration | Est. Cost (2 hours) |
|----------|--------------|---------------------|
| ECS Fargate — Service_B | 1 task × 0.25 vCPU × 0.5 GB (runs continuously) | ~$0.024 |
| ECS Fargate — Service_A | 1 task × 0.25 vCPU × 0.5 GB (runs ~30 seconds) | < $0.01 |
| ECS Fargate — Service_C | 1 task × 0.25 vCPU × 0.5 GB (runs ~30 seconds) | < $0.01 |
| ECR storage | 2 small images (~100 MB total) | < $0.01 |
| CloudWatch Logs | Minimal log volume | < $0.01 |
| **Total** | | **< $0.10** |

Compared to the VPC Lattice lab (~$0.15 for 2 hours), the JWT lab is slightly cheaper because there are no VPC Lattice per-hour or data-processing charges. The only costs are Fargate compute and minimal storage.

