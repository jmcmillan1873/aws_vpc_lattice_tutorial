# Prerequisites

Everything you need before starting any lab in this repository.

## AWS Account

- A **clean AWS account or region** with no pre-existing VPC Lattice resources, ECS clusters, or conflicting IAM roles
- No dependency on pre-existing resources — each lab deploys everything from scratch
- For a learning environment, `AdministratorAccess` avoids permission issues. For shared accounts, see the [IAM Permissions](#aws-iam-permissions) section below.

## Environment: AWS CloudShell (Recommended)

All labs are written for **AWS CloudShell**. It has the AWS CLI and Docker pre-installed, your credentials are automatically available, and there's nothing to configure before you start.

To open CloudShell, click the terminal icon in the top navigation bar of the AWS Console, or go to [console.aws.amazon.com/cloudshell](https://console.aws.amazon.com/cloudshell). Make sure you open it in the same region you plan to deploy to.

### Install Terraform in CloudShell

Terraform isn't pre-installed in CloudShell. Run this once per CloudShell session:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf -y install terraform
```

### Configure Terraform Plugin Cache

CloudShell's home directory has limited disk space (1 GB), so redirect the Terraform plugin cache to `/tmp` before running any `terraform init`:

```bash
export TF_PLUGIN_CACHE_DIR="/tmp/tf-plugin-cache"
mkdir -p $TF_PLUGIN_CACHE_DIR
```

> **Using a different environment?** The commands in these labs should work in any bash-compatible shell with the AWS CLI, Docker, and Terraform installed. You'll need to handle credential configuration and any environment differences yourself — but you probably already know that.

## CLI Tools

If you prefer to run the labs locally instead of CloudShell, you'll need:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.14.0 | Infrastructure deployment |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | AWS operations, ECR login, ECS run-task |
| [Docker](https://docs.docker.com/get-docker/) | Latest stable | Build and push container images |

## Terraform Provider

All labs use the HashiCorp AWS provider:

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

The IAM user or role running Terraform and AWS CLI commands needs permissions for the services used by each lab. The common set across all labs:

| Service | Permissions |
|---------|------------|
| **VPC** | `ec2:CreateVpc`, `ec2:CreateSubnet`, `ec2:CreateInternetGateway`, `ec2:CreateRouteTable`, `ec2:CreateRoute`, `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupEgress`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:DescribeVpcs`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups`, `ec2:DeleteVpc`, `ec2:DeleteSubnet`, `ec2:DeleteInternetGateway`, `ec2:DeleteSecurityGroup` |
| **ECS** | `ecs:CreateCluster`, `ecs:RegisterTaskDefinition`, `ecs:CreateService`, `ecs:RunTask`, `ecs:DescribeTasks`, `ecs:ListTasks`, `ecs:DeleteCluster`, `ecs:DeleteService`, `ecs:DeregisterTaskDefinition` |
| **IAM** | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:PassRole`, `iam:GetRole`, `iam:DeleteRole`, `iam:DeleteRolePolicy`, `iam:DetachRolePolicy` |
| **ECR** | `ecr:CreateRepository`, `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:DeleteRepository` |
| **CloudWatch Logs** | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`, `logs:GetLogEvents`, `logs:FilterLogEvents`, `logs:DeleteLogGroup` |

Individual labs may require additional permissions (e.g. VPC Lattice permissions for the VPC Lattice lab). See each lab's README for lab-specific requirements.

## Time and Cost

| Lab | Time | Estimated Cost (2 hours) |
|-----|------|--------------------------|
| [VPC Lattice](../labs/vpc-lattice/) | 30–45 minutes | < $0.15 |
| [JWT](../labs/jwt/) | 30–45 minutes | < $0.10 |

> Run the Cleanup section in each lab promptly after completing it to avoid ongoing charges. See [Cost Estimates](COST.md) for a full breakdown.
