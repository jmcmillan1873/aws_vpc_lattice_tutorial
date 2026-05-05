# Cost Estimates

This tutorial is designed for minimal cost. All resources use the smallest available sizes and can be destroyed immediately after testing.

## Lab Cost Breakdown (1–2 hours)

| Resource | Configuration | Hourly Rate | Est. Cost (2 hours) |
|----------|--------------|-------------|---------------------|
| **ECS Fargate - Service_B** | 1 task × 0.25 vCPU × 0.5 GB (runs continuously) | ~$0.012/hr | ~$0.024 |
| **ECS Fargate - Service_A** | 1 task × 0.25 vCPU × 0.5 GB (runs ~30 seconds) | ~$0.012/hr | < $0.01 |
| **ECS Fargate - Service_C** | 1 task × 0.25 vCPU × 0.5 GB (runs ~30 seconds) | ~$0.012/hr | < $0.01 |
| **VPC Lattice service** | 1 service (hourly charge) | ~$0.025/hr | ~$0.05 |
| **VPC Lattice data processing** | Minimal bytes for lab traffic | $0.025/GB | < $0.01 |
| **ECR storage** | 2 small images (~100 MB total) | $0.10/GB/month | < $0.01 |
| **CloudWatch Logs** | Minimal log volume | $0.50/GB ingested | < $0.01 |
| | | **Total estimate** | **< $0.15** |

> **Total for 1–2 hours: well under $1.** The dominant costs are the VPC Lattice service hourly charge and the continuously-running Service_B Fargate task.

## Why Public Subnets?

This tutorial uses **public subnets with auto-assigned public IPs** purely to minimise cost in a learning environment. This avoids:

- **NAT Gateway**: ~$0.045/hour + $0.045/GB data processing - would cost more than all other lab resources combined
- **VPC endpoints for ECR/CloudWatch**: ~$0.01/hour per endpoint × multiple endpoints needed

For production workloads, you would typically use **private subnets** with either:
- **VPC endpoints** for ECR, CloudWatch Logs, and other AWS services (recommended for security)
- **NAT Gateway** for general internet access (simpler but more expensive)

---

## Production Cost Levers

If you were to evolve this pattern into a production service mesh, here are the key cost drivers and how to manage them:

### VPC Lattice Costs at Scale

| Component | Pricing | Cost Lever |
|-----------|---------|------------|
| **Service hourly charge** | ~$0.025/hr per service (~$18/month) | Consolidate related endpoints behind fewer Lattice services where possible |
| **Data processing** | $0.025/GB | Minimise payload sizes; use compression; cache responses where appropriate |
| **Request count** | Included in data processing | Batch requests where feasible; avoid chatty service-to-service patterns |

### ECS Fargate Costs at Scale

| Component | Pricing | Cost Lever |
|-----------|---------|------------|
| **vCPU** | ~$0.04048/hr per vCPU | Right-size tasks based on actual CPU utilisation metrics |
| **Memory** | ~$0.004445/hr per GB | Right-size memory; avoid over-provisioning |
| **Spot capacity** | Up to 70% discount | Use Fargate Spot for non-critical or retry-tolerant workloads |
| **Savings Plans** | Up to 50% discount | Commit to 1-year or 3-year compute savings plans for steady-state workloads |

### Networking Costs at Scale

| Component | Pricing | Cost Lever |
|-----------|---------|------------|
| **NAT Gateway** | $0.045/hr + $0.045/GB | Use VPC endpoints for AWS services to avoid NAT for most traffic |
| **VPC endpoints** | ~$0.01/hr per endpoint per AZ | Share endpoints across services in the same VPC; consolidate AZs where resilience allows |
| **Cross-AZ data transfer** | $0.01/GB each way | Co-locate communicating services in the same AZ where resilience requirements allow |

### Observability Costs at Scale

| Component | Pricing | Cost Lever |
|-----------|---------|------------|
| **CloudWatch Logs ingestion** | $0.50/GB | Set appropriate log levels; use structured logging; filter at source |
| **CloudWatch Logs storage** | $0.03/GB/month | Set retention policies (7–30 days for most operational logs) |
| **CloudTrail** | $2.00 per 100K management events | Use data events selectively; filter to relevant services only |

### Cost Optimisation Strategies

1. **Right-size early**: Monitor CPU and memory utilisation for 2 weeks before committing to task sizes
2. **Use Savings Plans**: For steady-state workloads, compute savings plans provide significant discounts
3. **Consolidate Lattice services**: Each service incurs an hourly charge - group related endpoints where it makes architectural sense
4. **Set log retention**: Default CloudWatch retention is indefinite; set 7–30 day retention for operational logs
5. **Monitor data transfer**: Cross-AZ and internet-bound data transfer adds up quickly at scale
6. **Consider Fargate Spot**: For batch jobs, background processing, or services with retry logic

### Example: Production Monthly Estimate (3 services, multi-AZ)

| Component | Configuration | Monthly Cost |
|-----------|--------------|-------------|
| ECS Fargate (3 services) | 3 × 0.5 vCPU × 1 GB, 2 tasks each (multi-AZ) | ~$90 |
| VPC Lattice (2 services) | 2 Lattice services + 10 GB/month data | ~$36 + $0.25 |
| VPC endpoints | 4 endpoints × 2 AZs | ~$58 |
| CloudWatch Logs | 5 GB/month ingestion, 30-day retention | ~$2.50 + $0.15 |
| **Total** | | **~$187/month** |

> This is a rough estimate for a minimal production setup. Actual costs depend heavily on traffic volume, task sizing, and region.
