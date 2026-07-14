output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "k3s_sg_id" {
  value = aws_security_group.k3s.id
}

output "nlb_sg_id" {
  value = aws_security_group.nlb.id
}
