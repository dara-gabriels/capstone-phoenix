variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "nlb_sg_id" {
  type = string
}

variable "worker_instance_ids" {
  description = "EC2 instance IDs of the k3s workers, to register as NLB targets."
  type        = list(string)
}

variable "http_node_port" {
  description = "NodePort that ingress-nginx's Service exposes HTTP on (Helm value controller.service.nodePorts.http)."
  type        = number
  default     = 30080
}

variable "https_node_port" {
  description = "NodePort that ingress-nginx's Service exposes HTTPS on (Helm value controller.service.nodePorts.https)."
  type        = number
  default     = 30443
}
