provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# S3 bucket names are globally unique across all of AWS, so the account ID
# is appended - "taskapp-terraform-state" alone will collide with someone
# else's bucket the moment two people run this capstone.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Environment = var.environment
  }
}

# Enable versioning for the S3 bucket
# This ensures that we can recover previous versions of the state file in case of accidental deletion or corruption.
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the S3 bucket using AWS KMS to ensure that the Terraform state file is stored securely.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Create a DynamoDB table for Terraform state locking
# This table will be used to manage locks on the Terraform state file, preventing concurrent modifications that could lead to conflicts or corruption.
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "taskapp-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-lock"
    Environment = var.environment
  }
}
