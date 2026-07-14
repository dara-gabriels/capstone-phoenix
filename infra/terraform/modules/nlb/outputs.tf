output "dns_name" {
  description = "Point your domain's DNS record at this (CNAME, or an ALIAS/A record if your DNS provider supports ALIAS-to-NLB)."
  value       = aws_lb.taskapp.dns_name
}

output "zone_id" {
  value = aws_lb.taskapp.zone_id
}
