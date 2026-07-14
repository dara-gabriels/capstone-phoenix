# Remote state backend.
#
# Terraform does not allow variables inside a `backend` block, so these
# values are hardcoded here. If you rename the bucket/table, update this
# file and re-run `terraform init -reconfigure`.
#
# Bootstrap these two resources ONCE - via terraform/terraform-backend/
# (see that directory's README) - BEFORE running `terraform init` here.
# You cannot store the state of the state backend in the backend itself.

terraform {
  backend "s3" {
    bucket         = "taskapp-terraform-state-717827130829"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "taskapp-terraform-locks"
    encrypt        = true
  }
}
