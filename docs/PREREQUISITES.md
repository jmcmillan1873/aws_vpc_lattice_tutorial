# Prerequisites

Everything you need before starting the tutorial.

## AWS Account

- A **clean AWS account or region** with no pre-existing VPC Lattice resources, ECS clusters, or conflicting IAM roles
- No dependency on pre-existing resources - the tutorial deploys everything from scratch

## CLI Tools

This tutorial is written for **AWS CloudShell**, which has the AWS CLI and Docker pre-installed. You'll need to install Terraform manually - see the individual lab READMEs for the exact commands.

If you prefer to run the tutorial locally, you'll need:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.14.0 | Infrastructure deployment |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | AWS operations, ECR login, ECS run-task |
| [Docker](https://docs.docker.com/get-docker/) | Latest stable | Build and push container images |

## Terraform Provider

The lab uses the HashiCorp AWS provider:

```hcl
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

## AWS IAM Permissions

The IAM user or role running Terraform and AWS CLI commands needs the following minimum permissions:

| Service | Permissions |
|---------|------------|
| **VPC** | `ec2:CreateVpc`, `ec2:CreateSubnet`, `ec2:CreateInternetGateway`, `ec2:CreateRouteTable`, `ec2:CreateRoute`, `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupEgress`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:DescribeVpcs`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups`, `ec2:DescribeManagedPrefixLists`, `ec2:DeleteVpc`, `ec2:DeleteSubnet`, `ec2:DeleteInternetGateway`, `ec2:DeleteSecurityGroup` |
| **ECS** | `ecs:CreateCluster`, `ecs:RegisterTaskDefinition`, `ecs:CreateService`, `ecs:RunTask`, `ecs:DescribeTasks`, `ecs:ListTasks`, `ecs:DeleteCluster`, `ecs:DeleteService`, `ecs:DeregisterTaskDefinition` |
| **IAM** | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:PassRole`, `iam:GetRole`, `iam:DeleteRole`, `iam:DeleteRolePolicy`, `iam:DetachRolePolicy` |
| **ECR** | `ecr:CreateRepository`, `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:DeleteRepository` |
| **VPC Lattice** | `vpc-lattice:CreateServiceNetwork`, `vpc-lattice:CreateService`, `vpc-lattice:CreateTargetGroup`, `vpc-lattice:CreateListener`, `vpc-lattice:CreateServiceNetworkVpcAssociation`, `vpc-lattice:PutAuthPolicy`, `vpc-lattice:RegisterTargets`, `vpc-lattice:DeleteServiceNetwork`, `vpc-lattice:DeleteService`, `vpc-lattice:DeleteTargetGroup`, `vpc-lattice:DeleteListener` |
| **CloudWatch Logs** | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`, `logs:GetLogEvents`, `logs:FilterLogEvents`, `logs:DeleteLogGroup` |

> **Tip**: For a learning environment, you can use an IAM user with `AdministratorAccess` to avoid permission issues. For production or shared accounts, scope permissions to the minimum set above.

## Time Estimate

| Metric | Estimate |
|--------|----------|
| **Time to complete** | 30–45 minutes |
| **Estimated cost** | < $0.15 for 1–2 hours |

> Run the Cleanup section promptly after completing the tutorial to avoid ongoing charges. See [Cost Estimates](COST.md) for a full breakdown.
