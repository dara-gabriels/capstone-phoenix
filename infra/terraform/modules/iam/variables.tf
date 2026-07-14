variable "project_name" {
  type = string
}

variable "github_org" {
  description = "GitHub org/user that owns the infrastructure repo"
  type        = string
  default     = "ts-a-devops"
}

variable "github_infra_repo" {
  description = "Name of the repo allowed to assume this role"
  type        = string
  default     = "infrastructure"
}

variable "state_bucket_name" {
  type = string
}

variable "lock_table_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  description = "AWS account ID - used to build the exact DynamoDB table ARN"
  type        = string
}
