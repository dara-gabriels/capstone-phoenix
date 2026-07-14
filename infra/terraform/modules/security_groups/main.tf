# Least-privilege, SG-only network security. There is deliberately no
# host-level firewall (no ufw/iptables rules maintained by Ansible) - the
# security boundary is entirely the AWS Security Group layer, which is
# easier to audit, versioned in this one place, and can't drift between
# nodes the way per-host firewall rules can.
#
# Public exposure is limited to 80/443, and only on the load balancer - see
# the nlb module. No instance, including the k3s nodes, has 80/443 (or
# anything else) open to 0.0.0.0/0 directly.

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Bastion host - SSH from admin IP only. Sole entry point for SSH and for reaching the k3s API."
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
  description = "K3s cluster nodes (master + workers). No public ingress at all - app traffic arrives via the NLB, admin traffic via the bastion."
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "Kubernetes API (6443) from bastion only - never from 0.0.0.0/0"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Ingress-nginx NodePorts, from the NLB only"
    from_port   = 30080
    to_port     = 30443
    protocol    = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-sg"
    Environment = var.environment
  }
}

# Node-to-node cluster plumbing: k3s flannel VXLAN, kubelet, and API traffic
# between the master and workers themselves (join, heartbeats, exec/logs).
resource "aws_security_group_rule" "k3s_flannel_vxlan" {
  type                     = "ingress"
  description              = "Flannel VXLAN between K3s nodes"
  from_port                = 8472
  to_port                  = 8472
  protocol                 = "udp"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = aws_security_group.k3s.id
}

resource "aws_security_group_rule" "k3s_kubelet" {
  type                     = "ingress"
  description              = "Kubelet API between K3s nodes"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = aws_security_group.k3s.id
}

resource "aws_security_group_rule" "k3s_api_between_nodes" {
  type                     = "ingress"
  description              = "Kubernetes API between K3s nodes (agent-to-server join/heartbeat)"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = aws_security_group.k3s.id
}

resource "aws_security_group_rule" "nlb_to_k3s_nodeports" {
  type                     = "egress"
  description              = "To k3s NodePorts only"
  from_port                = 30080
  to_port                  = 30443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nlb.id
  source_security_group_id = aws_security_group.k3s.id
}

# The NLB is the only thing in this whole architecture allowed to talk to
# the world on 80/443. It has no compute of its own - AWS-managed - so
# opening it to 0.0.0.0/0 does not put any instance directly on the
# internet; it forwards to the k3s NodePorts, which are only reachable from
# this SG (see k3s SG rule above).
resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-${var.environment}-nlb-sg"
  description = "Public entry point: 80/443 from the internet, forwarded to k3s NodePorts only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the world (redirected to HTTPS by ingress-nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the world"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To k3s NodePorts only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nlb-sg"
    Environment = var.environment
  }
}
