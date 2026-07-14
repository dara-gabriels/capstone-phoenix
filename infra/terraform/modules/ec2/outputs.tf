output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "SSH here first: ssh -i <key>.pem ubuntu@<this-ip>"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "k3s_master_instance_id" {
  value = aws_instance.k3s_master.id
}

output "k3s_master_private_ip" {
  description = "Private IP of the K3s control plane node (reached only via the bastion - 6443 is never public)"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_worker_instance_ids" {
  value = aws_instance.k3s_worker[*].id
}

output "k3s_worker_private_ips" {
  description = "Private IPs of all K3s worker nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}
