output "aws_availability_zones" {
  description = "List of availability zones in the region"
  value       = module.core.availability_zones
}

output "ubuntu_ami_id" {
  description = "The ID of the latest Ubuntu 24.04 AMI in the specified region"
  value       = module.core.ubuntu_ami_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC created"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "bastion_public_ip" {
  description = "SSH here first: ssh -i <key>.pem ubuntu@<this-ip>"
  value       = module.ec2.bastion_public_ip
}

output "k3s_master_private_ip" {
  value = module.ec2.k3s_master_private_ip
}

output "k3s_worker_private_ips" {
  value = module.ec2.k3s_worker_private_ips
}

output "k3s_worker_instance_ids" {
  value = module.ec2.k3s_worker_instance_ids
}

output "nlb_dns_name" {
  description = "Point your domain's DNS (CNAME, or your provider's ALIAS/flatten-CNAME record for the apex) at this."
  value       = module.nlb.dns_name
}

output "terraform_ci_role_arn" {
  description = "Set this as the AWS_TERRAFORM_ROLE_ARN secret in the infrastructure repo"
  value       = module.iam.terraform_ci_role_arn
}
