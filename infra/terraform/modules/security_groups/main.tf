# Least-privilege, SG-only network security. There is deliberately no
# host-level firewall (no ufw/iptables rules maintained by Ansible) - the
# security boundary is entirely the AWS Security Group layer.
#
# Every single rule below is its own aws_vpc_security_group_*_rule
# resource - never an inline ingress/egress block inside
# aws_security_group. Mixing inline blocks with standalone rule resources
# on the same SG is a known Terraform race: both get pushed to the AWS
# API in the same apply, and one can silently clobber the other (this bit
# us in practice - the SSH rule went missing on first apply). One rule,
# one resource, no race, full stop.

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Bastion host - SSH from admin IP only. Sole entry point for SSH and for reaching the k3s API."
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description        = "SSH from admin IP"
  ip_protocol         = "tcp"
  from_port           = 22
  to_port             = 22
  cidr_ipv4           = var.admin_ip_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_outbound" {
  security_group_id = aws_security_group.bastion.id
  description        = "Allow all outbound"
  ip_protocol         = "-1"
  cidr_ipv4           = "0.0.0.0/0"
}

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
  description = "K3s cluster nodes (master + workers). No public ingress at all - app traffic arrives via the NLB, admin traffic via the bastion."
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "k3s_ssh_from_bastion" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "SSH from bastion only"
  ip_protocol                   = "tcp"
  from_port                     = 22
  to_port                       = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_api_from_bastion" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "Kubernetes API (6443) from bastion only - never from 0.0.0.0/0"
  ip_protocol                   = "tcp"
  from_port                     = 6443
  to_port                       = 6443
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_nodeports_from_nlb" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "Ingress-nginx NodePorts, from the NLB only"
  ip_protocol                   = "tcp"
  from_port                     = 30080
  to_port                       = 30443
  referenced_security_group_id = aws_security_group.nlb.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_flannel_vxlan" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "Flannel VXLAN between K3s nodes"
  ip_protocol                   = "udp"
  from_port                     = 8472
  to_port                       = 8472
  referenced_security_group_id = aws_security_group.k3s.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_kubelet" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "Kubelet API between K3s nodes"
  ip_protocol                   = "tcp"
  from_port                     = 10250
  to_port                       = 10250
  referenced_security_group_id = aws_security_group.k3s.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_api_between_nodes" {
  security_group_id           = aws_security_group.k3s.id
  description                  = "Kubernetes API between K3s nodes (agent-to-server join/heartbeat)"
  ip_protocol                   = "tcp"
  from_port                     = 6443
  to_port                       = 6443
  referenced_security_group_id = aws_security_group.k3s.id
}

resource "aws_vpc_security_group_egress_rule" "k3s_all_outbound" {
  security_group_id = aws_security_group.k3s.id
  description        = "Allow all outbound"
  ip_protocol         = "-1"
  cidr_ipv4           = "0.0.0.0/0"
}

# The NLB is the only thing in this whole architecture allowed to talk to
# the world on 80/443. It has no compute of its own - AWS-managed - so
# opening it to 0.0.0.0/0 does not put any instance directly on the
# internet; it forwards to the k3s NodePorts, which are only reachable
# from this SG.
resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-${var.environment}-nlb-sg"
  description = "Public entry point: 80/443 from the internet, forwarded to k3s NodePorts only"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nlb-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_http" {
  security_group_id = aws_security_group.nlb.id
  description        = "HTTP from the world (redirected to HTTPS by ingress-nginx)"
  ip_protocol         = "tcp"
  from_port           = 80
  to_port             = 80
  cidr_ipv4           = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "nlb_https" {
  security_group_id = aws_security_group.nlb.id
  description        = "HTTPS from the world"
  ip_protocol         = "tcp"
  from_port           = 443
  to_port             = 443
  cidr_ipv4           = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "nlb_all_outbound" {
  security_group_id = aws_security_group.nlb.id
  description        = "To k3s NodePorts (and anywhere else the LB health checks need)"
  ip_protocol         = "-1"
  cidr_ipv4           = "0.0.0.0/0"
}
