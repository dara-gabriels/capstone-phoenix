variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type = string
}

variable "project_name" {
  type    = string
  default = "taskapp"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.10.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.2.0/24", "10.0.20.0/24"]
}

variable "private_subnet_b_cidr" {
  type    = string
  default = "10.0.30.0/24"
}

variable "admin_ip_cidr" {
  description = "Your IP in CIDR form, e.g. 203.0.113.4/32 - run `curl -s ifconfig.me` and append /32."
  type        = string
}

variable "key_pair_name" {
  description = "Name of an EC2 key pair that already exists in this region (aws ec2 create-key-pair)."
  type        = string
  default     = "taskapp_key_pair"
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
  type    = number
  default = 2
}

variable "ingress_http_node_port" {
  description = "Must match ingress-nginx Helm value controller.service.nodePorts.http"
  type        = number
  default     = 30080
}

variable "ingress_https_node_port" {
  description = "Must match ingress-nginx Helm value controller.service.nodePorts.https"
  type        = number
  default     = 30443
}

variable "state_bucket_name" {
  type = string
}

variable "max_allocated_storage" {
  type    = number
  default = 100
}

variable "lock_table_name" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_infra_repo" {
  type = string
}
