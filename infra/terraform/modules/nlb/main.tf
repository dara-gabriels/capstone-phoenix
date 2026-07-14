# Public entry point for the whole app. Terminates nothing itself (TLS is
# terminated by cert-manager/ingress-nginx inside the cluster) - it's a
# plain L4 forwarder to the k3s workers' NodePorts. This is what your
# domain's DNS record (A/ALIAS, or CNAME on the apex-alt) points at.
#
# Why an NLB instead of putting public IPs on the k3s nodes themselves:
# the nodes stay fully private (no direct internet exposure at the
# instance level, matches the "6443 never public" posture for the whole
# node, not just port 6443), and the DNS target is stable even if a
# worker is replaced - the NLB always forwards to whichever workers are
# currently registered and healthy.

resource "aws_lb" "taskapp" {
  name               = "${var.project_name}-${var.environment}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
  security_groups    = [var.nlb_sg_id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nlb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "http" {
  name        = "${var.project_name}-${var.environment}-tg-http"
  port        = var.http_node_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }
}

resource "aws_lb_target_group" "https" {
  name        = "${var.project_name}-${var.environment}-tg-https"
  port        = var.https_node_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.taskapp.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.taskapp.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

# Register every worker as a target. Workers run ingress-nginx as a
# DaemonSet exposed via a NodePort Service, so any worker can receive
# traffic for either port. If a worker is replaced, re-run
# terraform apply to re-register the new instance ID.
resource "aws_lb_target_group_attachment" "http" {
  count            = length(var.worker_instance_ids)
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = var.worker_instance_ids[count.index]
  port             = var.http_node_port
}

resource "aws_lb_target_group_attachment" "https" {
  count            = length(var.worker_instance_ids)
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = var.worker_instance_ids[count.index]
  port             = var.https_node_port
}
