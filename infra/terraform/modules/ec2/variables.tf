variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EC2 instances will be launched."
  type        = string
}

variable "public_subnet_id" {
  type        = string
  description = "The ID of the public subnet for the bastion host."
}

variable "private_subnet_a_id" {
  description = "Private subnet A (AZ-a) ID for the k3s master + half the workers."
  type        = string
}

variable "private_subnet_b_id" {
  description = "Private subnet B (AZ-b) ID, so workers spread across 2 AZs."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion instance."
  type        = string
}

variable "k3s_sg_id" {
  description = "Security group ID for k3s master + worker instances."
  type        = string
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "k3s_master_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "k3s_worker_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "k3s_worker_count" {
  description = "Number of k3s worker (agent) nodes. Minimum 2 to satisfy the 'real multi-node scheduling' requirement."
  type        = number
  default     = 2

  validation {
    condition     = var.k3s_worker_count >= 2
    error_message = "The capstone requires at least 1 control-plane + 2 workers (3 nodes minimum). k3s_worker_count must be >= 2."
  }
}

variable "key_pair_name" {
  description = "The name of the SSH key pair to use for the EC2 instances."
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI to use for the EC2 instances."
  type        = string
}
