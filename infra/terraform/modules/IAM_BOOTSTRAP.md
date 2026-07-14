# IAM bootstrap - read this before your first `terraform apply`

The `iam` module creates the very IAM role that GitHub Actions later
uses to run `terraform apply`. That role can't create itself - there
is an unavoidable one-time bootstrap step:

1. **First apply: run locally**, authenticated with your own IAM
   user/admin credentials (`aws configure` or SSO), not from CI:
   ```bash
   cd terraform/environments/prod
   terraform init
   terraform apply
   ```
   This creates the VPC, EC2 instances, security groups, AND the
   `taskapp-terraform-ci` role with its GitHub OIDC trust policy.

2. **Copy the output** into the `infrastructure` repo's GitHub secret:
   ```bash
   terraform output terraform_ci_role_arn
   # -> paste into repo Settings -> Secrets -> AWS_TERRAFORM_ROLE_ARN
   ```

3. **From here on, all applies go through CI** (Phase 6's
   `terraform.yml` workflow) using that role via OIDC - no human ever
   needs long-lived AWS credentials again, including you. If the role
   itself ever needs to change (e.g. you add a new AWS service the
   pipeline needs to touch), that change still has to be applied
   locally with admin credentials once, same as this initial bootstrap,
   since a role can't grant itself new permissions it doesn't have
   (and the explicit `DenySelfPrivilegeEscalation` statement makes
   sure of that even if someone tries).

This is the one deliberate exception to "no human ever touches AWS
directly" - every GitOps and CI/CD system has some root of trust that
has to be established by a human at least once.
