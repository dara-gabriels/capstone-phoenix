data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ===========================================================================
# 🚀 STRATEGIC INTERFACE EXPORTS (DON'T OMIT THESE)
# ===========================================================================

output "availability_zones" {
  description = "List of active availability zones in the running region"
  value       = data.aws_availability_zones.available.names
}

output "ubuntu_ami_id" {
  description = "The verified target ID of the resolved Ubuntu 24.04 AMI"
  value       = data.aws_ami.ubuntu.id
}
