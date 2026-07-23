packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

data "amazon-ami" "al2023" {
  filters = {
    name                = "al2023-ami-*"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
  owners      = ["amazon"]
  most_recent = true
  region      = var.region
}

source "amazon-ebs" "seeo" {
  ami_name      = "seeo-hardened-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.region
  source_ami    = data.amazon-ami.al2023.id
  ssh_username  = "ec2-user"

  tags = {
    Name        = "seeo-hardened"
    ManagedBy   = "packer"
    Project     = "seeo"
  }
}

build {
  sources = ["source.amazon-ebs.seeo"]

  provisioner "shell" {
    script = "scripts/bootstrap.sh"
  }
}
