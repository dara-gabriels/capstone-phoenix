output "vpc_id" {
  description = "ID of the VPC created"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC created"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets created"
  value       = aws_subnet.public[*].id
}

output "private_subnet_a_id" {
  description = "ID of the first isolated private subnet (Private A)"
  value       = aws_subnet.private_a[0].id
}

output "private_subnet_b_id" {
  description = "ID of the second isolated private subnet (Private B)"
  value       = aws_subnet.private_b.id
}

output "private_subnet_ids" {
  description = "Plural array containing all secure private subnet strings"
  value = [
    aws_subnet.private_a[0].id,
    aws_subnet.private_b.id
  ]
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway created"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway created"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}