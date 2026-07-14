variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_ip_cidr" {
  description = "Your IP in CIDR form (e.g. 203.0.113.4/32). Only this IP may SSH to the bastion or reach 6443."
  type        = string
}
