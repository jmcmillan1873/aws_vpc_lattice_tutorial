# Hint: Allowing Service_C to Connect to Service_B

This document walks you through the solution to the knowledge check in the [Lab Walkthrough](WALKTHROUGH.md). Only read this if you've had a genuine attempt first.

---

## What needs to change

Recall the two gates a caller must pass:

1. The caller's IAM role must have `vpc-lattice-svcs:Invoke` permission
2. The VPC Lattice auth policy on the target service must permit the caller's principal

Service_C currently fails at gate 1. Even if you fix that, it will then fail at gate 2. You need to fix both.

---

## Step 1 - Add the identity-based policy to Service_C's role

1. Open the [IAM Console - Roles](https://console.aws.amazon.com/iam/home#/roles) and search for `lab-service-c-task-role`
2. Click on the role, then click the **Permissions** tab
3. Click **Add permissions** > **Create inline policy**
4. Switch to the **JSON** editor and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "vpc-lattice-svcs:Invoke",
      "Resource": "*"
    }
  ]
}
```

5. Click **Next**, give the policy a name (e.g. `lattice-invoke`), then click **Create policy**

Service_C can now attempt VPC Lattice calls. But it will still get a 403 - gate 2 is still blocking it.

---

## Step 2 - Update the Lattice auth policy to permit Service_C

1. Open the [VPC Console](https://console.aws.amazon.com/vpcconsole/home) and click **Lattice services** in the left nav
2. Click on `lab-service-b`, then click the **Access** tab
3. Click **Edit** on the auth policy
4. You need to add Service_C's role ARN as a second principal. The updated policy should look like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::<account_id>:role/lab-service-a-task-role",
          "arn:aws:iam::<account_id>:role/lab-service-c-task-role"
        ]
      },
      "Action": "vpc-lattice-svcs:Invoke",
      "Resource": "*"
    }
  ]
}
```

Replace `<account_id>` with your AWS account ID. You can find it in the top-right corner of the console, or by running:

```bash
aws sts get-caller-identity --query Account --output text
```

5. Click **Save**

---

## Step 3 - Re-run Service_C and verify

Run Service_C again using the same `aws ecs run-task` command from the testing section, then check the logs:

```bash
aws logs tail /ecs/service-c --since 5m --region $AWS_REGION
```

You should now see:

```
Response status: 200
Response body: {"message": "Hello from Service_B!", "timestamp": "..."}
```

---

## What you've just demonstrated

By making two changes - one to IAM, one to the Lattice auth policy - you've granted Service_C access to Service_B. Neither change touched any application code. Service_B's `app.py` is completely unchanged.

This is the pattern in practice: access control is managed entirely through IAM and Lattice policies, not through application logic.

---

## Tidy up

If you want to restore the original lab state (Service_C denied), reverse both changes:

1. In IAM, delete the inline policy you added to `lab-service-c-task-role`
2. In VPC Lattice, edit the auth policy back to only permit `lab-service-a-task-role`
