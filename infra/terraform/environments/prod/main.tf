module "core" {
  source       = "../../modules/core"
  project_name = var.project_name
  environment  = var.environment
}

module "vpc" {
  source                = "../../modules/vpc"
  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  private_subnet_b_cidr = var.private_subnet_b_cidr
}

module "security_groups" {
  source        = "../../modules/security_groups"
  project_name  = var.project_name
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  admin_ip_cidr = var.admin_ip_cidr
}

module "ec2" {
  source = "../../modules/ec2"

  project_name  = var.project_name
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  ami_id        = module.core.ubuntu_ami_id
  key_pair_name = "taskapp_key_pair"

  bastion_instance_type    = var.bastion_instance_type
  k3s_master_instance_type = var.k3s_master_instance_type
  k3s_worker_instance_type = var.k3s_worker_instance_type
  k3s_worker_count         = var.k3s_worker_count

  public_subnet_id    = module.vpc.public_subnet_ids[0]
  private_subnet_a_id = module.vpc.private_subnet_ids[0]
  private_subnet_b_id = module.vpc.private_subnet_ids[1]

  bastion_sg_id = module.security_groups.bastion_sg_id
  k3s_sg_id     = module.security_groups.k3s_sg_id
}

# Public entry point for the app - forwards to ingress-nginx's NodePorts on
# the k3s workers. See terraform/modules/nlb for why this exists instead of
# public IPs on the nodes themselves.
module "nlb" {
  source = "../../modules/nlb"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  nlb_sg_id           = module.security_groups.nlb_sg_id
  worker_instance_ids = module.ec2.k3s_worker_instance_ids
  http_node_port      = var.ingress_http_node_port
  https_node_port     = var.ingress_https_node_port
}

module "iam" {
  source            = "../../modules/iam"
  project_name      = var.project_name
  state_bucket_name = var.state_bucket_name
  lock_table_name   = var.lock_table_name
  aws_region        = var.aws_region
  aws_account_id    = var.aws_account_id
  github_org        = var.github_org
  github_infra_repo = var.github_infra_repo
}
