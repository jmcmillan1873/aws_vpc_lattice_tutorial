# FAQ & Troubleshooting

Common questions and solutions for issues you might encounter during the tutorial.

---

## Frequently Asked Questions

### How long does the tutorial take?

30–45 minutes from start to finish, including deployment, testing, and cleanup.

### How much does it cost?

Less than $0.15 for 1–2 hours. See [Cost Estimates](COST.md) for a full breakdown.

### Can I run this in an existing AWS account?

Yes, but we recommend using a clean region or sandbox account. The tutorial creates its own VPC, IAM roles, and other resources that won't conflict with existing infrastructure - but a sandbox account eliminates any risk.

### Why do Service_A and Service_C use the same Docker image?

To reinforce the teaching point: authorization is purely infrastructure-level (IAM), not application-level. The same code behaves differently based solely on which IAM role the task assumes.

### Why is there no NAT Gateway?

Cost. A NAT Gateway costs ~$0.045/hour - more than all other tutorial resources combined. Public IPs on Fargate tasks provide the same outbound connectivity at zero additional cost. This is fine for a tutorial but not recommended for production. See [NOTICE.md](NOTICE.md) for details.

### Can I use a different region?

Yes. Change the `aws_region` variable in both `phase1/variables.tf` and `phase3/variables.tf` within the lab you're running, and ensure your AWS CLI is configured for that region. VPC Lattice is available in most commercial regions.

### What's the difference between the identity-based policy and the auth policy?

- **Identity-based policy** (on the caller's IAM role): "Am I allowed to call VPC Lattice services?"
- **Auth policy** (on the Lattice service): "Is this specific caller allowed to reach me?"

Both must allow for the request to succeed. This is the dual authorization model.

---

## Troubleshooting

### Phase 1: Terraform Deployment

| Issue | Cause | Fix |
|-------|-------|-----|
| `Error: No valid credential sources found` | AWS CLI not configured | Run `aws configure` or set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` |
| `Error: error configuring Terraform AWS Provider` | Wrong region or missing provider | Verify `variables.tf` has a valid default region |
| `Error: creating EC2 VPC: UnauthorizedOperation` | Insufficient IAM permissions | Ensure your IAM user/role has VPC creation permissions (see [Prerequisites](PREREQUISITES.md)) |
| `Error: Failed to query available provider packages` | Network issue during init | Check internet connectivity; retry `terraform init` |

### Phase 2: Docker Build and Push

| Issue | Cause | Fix |
|-------|-------|-----|
| `no basic auth credentials` | ECR login expired or not run | Re-run `aws ecr get-login-password --region $AWS_REGION \| docker login ...` |
| `denied: Your authorization token has expired` | ECR token expired (12-hour lifetime) | Re-run the ECR login command |
| `Cannot connect to the Docker daemon` | Docker Desktop not running | Start Docker Desktop and wait for it to be ready |
| `error during connect: ... connection refused` | Docker daemon not listening | Restart Docker Desktop; on Windows ensure WSL2 backend is enabled |
| `requested access to the resource is denied` | Pushing to wrong repository URL | Verify `$CALLER_ECR_URL` and `$SERVICE_B_ECR_URL` match Phase 1 outputs |
| Build fails with `pip install` errors | Network issue inside Docker | Check Docker has internet access; try `docker build --no-cache` |

### Phase 3: ECS and VPC Lattice

| Issue | Cause | Fix |
|-------|-------|-----|
| `InvalidParameterException: Image does not exist` | Image not pushed or wrong URI | Verify images exist: `aws ecr describe-images --repository-name <prefix>/caller --region $AWS_REGION` |
| Target group shows `UNHEALTHY` | Service_B not responding on port 5000 | Check logs: `aws logs tail /ecs/service-b --since 5m --region $AWS_REGION` |
| ECS task stuck in `PROVISIONING` | Subnet can't reach internet | Verify route table has `0.0.0.0/0 → IGW` and subnet is associated |
| `Error: creating VPC Lattice Service Network VPC Association` | VPC already associated | Remove existing association or use a different VPC |
| Lattice service DNS not resolving | VPC association not yet active | Wait 1–2 minutes; check: `aws vpc-lattice list-service-network-vpc-associations --region $AWS_REGION` |

### Testing

| Issue | Cause | Fix |
|-------|-------|-----|
| Service_A gets 403 (unexpected) | Auth policy ARN doesn't match role ARN | Verify the ARN in `auth_policy.tf` matches `terraform -chdir=../phase1 output -raw service_a_task_role_arn` exactly |
| Service_C gets timeout instead of 403 | Network issue, not auth issue | Check VPC association is active; verify Lattice DNS resolves |
| No logs appearing | Task hasn't run yet or wrong log group | Wait 30s; verify task status: `aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks <task-arn> --region $AWS_REGION` |
| `An error occurred (InvalidParameterException)` in run-task | Malformed JSON in --overrides | Ensure JSON escaping is correct; try single-quoting the entire overrides value |

### Cleanup

| Issue | Cause | Fix |
|-------|-------|-----|
| Phase 3 destroy fails with dependency error | ECS tasks still running | Wait for tasks to stop, or force-stop: `aws ecs stop-task --cluster lab-cluster --task <task-arn> --region $AWS_REGION` |
| Phase 1 destroy fails with "resource in use" | Phase 3 not fully destroyed | Re-run Phase 3 destroy first |
| VPC deletion fails | ENIs still attached | Wait 5 minutes for ECS to release ENIs, then retry |
| Lost shell variables | Terminal closed | Re-export from Phase 1: `export CALLER_ECR_URL=$(terraform -chdir=phase1 output -raw caller_ecr_repository_url)` |

---

## Distinguishing Auth Denial from Network Failure

| Signal | Auth Denial (403) | Network Failure |
|--------|-------------------|-----------------|
| **Response time** | Fast (< 1 second) | Slow (timeout after 30+ seconds) |
| **HTTP status** | `403` | No HTTP response |
| **Response body** | `AccessDeniedException` | `ConnectionError` or `Timeout` |
| **Root cause** | IAM or Lattice policy | DNS, VPC association, or routing |

**Diagnosis approach:**

1. Check response time and status code first - a fast 403 means the network is fine, the problem is authorization
2. If you see a timeout, investigate network: VPC association active? DNS resolving? Route table correct?
3. If Service_A gets an unexpected 403, check the auth policy ARN matches the task role ARN exactly

---

## Still Stuck?

If you've tried the troubleshooting steps above and are still having issues:

1. Check CloudWatch Logs for the relevant service (`/ecs/service-a`, `/ecs/service-b`, `/ecs/service-c`)
2. Verify all Phase 1 outputs are being passed correctly to Phase 3
3. Ensure the VPC Lattice service status is `ACTIVE`: `aws vpc-lattice get-service --service-identifier <id> --region $AWS_REGION`
4. Check the target group has healthy targets: `aws vpc-lattice list-targets --target-group-identifier <id> --region $AWS_REGION`
5. Try destroying everything and redeploying from scratch - it takes under 10 minutes
