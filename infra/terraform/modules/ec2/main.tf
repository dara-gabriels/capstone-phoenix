# Only 3 kinds of node exist in this capstone: a bastion (admin access only,
# no app traffic), one k3s control-plane, and N k3s workers. There is no
# standalone frontend/backend/monitoring EC2 instance anymore - the app and
# the observability stack both run as workloads *inside* the cluster. That's
# the whole point of "Phoenix": everything moves off hand-run boxes and onto
# Kubernetes, reconciled by GitOps.

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted              = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion"
    Role        = "bastion"
    Environment = var.environment
  }
}

resource "aws_instance" "k3s_master" {
  ami                     = var.ami_id
  instance_type           = var.k3s_master_instance_type
  subnet_id               = var.private_subnet_a_id
  vpc_security_group_ids  = [var.k3s_sg_id]
  key_name                = var.key_pair_name
  disable_api_termination = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-master"
    Role        = "k3s-server"
    Environment = var.environment
  }
}

# Spread workers across both private subnets (both AZs) so a single AZ
# outage doesn't take the whole worker fleet down, and so
# topologySpreadConstraints in the app manifests have real separate
# hosts/racks to spread across.
resource "aws_instance" "k3s_worker" {
  count                   = var.k3s_worker_count
  ami                     = var.ami_id
  instance_type           = var.k3s_worker_instance_type
  subnet_id               = count.index % 2 == 0 ? var.private_subnet_a_id : var.private_subnet_b_id
  vpc_security_group_ids  = [var.k3s_sg_id]
  key_name                = var.key_pair_name
  disable_api_termination = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-worker-${count.index + 1}"
    Role        = "k3s-agent"
    Environment = var.environment
  }
}
