# Before You Begin

Welcome! This tutorial is presented in lab format - it's designed to help you learn VPC Lattice service-to-service authentication in a safe, self-contained environment. We encourage you to experiment, break things, and explore beyond the guided steps - that's how the best learning happens.

## What This Tutorial Is

- A **learning tool** for understanding VPC Lattice IAM authorization patterns
- A **minimal, self-contained** lab deployment that creates all resources from scratch
- A **starting point** for exploring service mesh authentication concepts on AWS

## What This Tutorial Is Not

- **Not production-ready code.** The Terraform and application code prioritise clarity and minimalism over resilience, security hardening, and operational best practices.
- **Not a reference architecture.** Production deployments require multi-AZ, private subnets, scoped IAM policies, monitoring, alerting, and much more.
- **Not a managed service.** There is no support, SLA, or guarantee of any kind.

## Your Responsibility

By using this tutorial, you acknowledge that:

- **You are responsible for any AWS costs incurred.** The tutorial deploys real AWS resources that cost money. While costs are minimal (< $0.15 for 1–2 hours), forgetting to clean up will result in ongoing charges.
- **You are responsible for the security of your AWS account.** This tutorial creates IAM roles, security groups, and network resources. Deploy in a dedicated sandbox account or isolated region - never in a production environment.
- **You use this code entirely at your own risk.** The author(s) accept no liability for costs, data loss, security incidents, or any other consequences arising from the use of this tutorial.

## Specific Non-Production Patterns

The following design choices are made for tutorial clarity and would need to change for production:

| Lab Pattern | Why It's Here | Production Alternative |
|-------------|---------------|----------------------|
| `Resource: "*"` in IAM policies | Lattice service ARN isn't known until deploy time | Scope to specific Lattice service ARN |
| Public subnets with public IPs | Avoids NAT Gateway cost (~$0.045/hr) | Private subnets + VPC endpoints |
| Single Availability Zone | Minimises resource count | Multi-AZ for resilience |
| No monitoring or alerting | Keeps the tutorial focused | CloudWatch alarms, dashboards, SNS |
| Mutable ECR image tags | Simplifies re-pushing during the tutorial | Immutable tags + image scanning |
| No encryption at rest | Not relevant to the teaching objective | KMS encryption on logs, ECR, etc. |
| `AdministratorAccess` suggested | Avoids permission debugging | Least-privilege IAM policies |

## Recommended Environment

- Deploy in a **sandbox AWS account** or a region you don't use for production workloads
- Use a **dedicated IAM user** rather than your root account or production credentials
- **Clean up promptly** after completing the tutorial (see the Cleanup section in each lab's README)

## Go Explore

With those caveats understood - have fun! The tutorial is yours to modify, extend, and learn from. If something breaks, that's often where the most interesting learning happens.
