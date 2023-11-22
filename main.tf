
# Provider info
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.0"
    }
    aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {
    
  }
}

#module info

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"
}

#Pull up the latest
data "aws_ami" "iam" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.*"]
  }

}

#Public Ip ssh 
data "http" "ip_public" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}
locals {
  public_ip =  jsondecode(data.http.ip_public.body)
}

#Key ssh 
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "this" {
  key_name = "lab02_nacho"
  public_key = tls_private_key.this.public_key_openssh
  
}

provider "aws" {
    shared_config_files = ["/home/nachi/.aws/config"]
    shared_credentials_files = ["/home/nachi/.aws/credentials"]
    region = var.region
}

variable "region" {
  type = string
}

variable "subnet" {
  type = string
}

variable "cidr" {
  type = string
}
#VPC 
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "Headscale"
  azs = [var.region]
  cidr = var.cidr
  public_subnets = [var.subnet]
}

#Exit node 

module "exit_node" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  name = "exit_node"
  instance_type = "t2.nano"
  key_name = aws_key_pair.this.key_name
  vpc_security_group_ids = []
  associate_public_ip_address = true

}


#Exit node nsg
#Needs to be open for connection, can be made an script for verifying IP of the user connecting? 
module "exit_node_nsg" {
  source = "terraform-aws-modules/security-group/aws"
  name = "Control_server"
  description = "Exit server NSG"
  vpc_id = module.vpc.vpc_id
   ingress_with_cidr_blocks = [
    {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr_blocks = "${module.control_server_ec2.private_ip}/32" 
    },
    {
    from_port = 23
    to_port = 65355
    ip_protocol = "tcp"
    cidr_blocks = "0.0.0.0/0" 
    }
    
  ]
 
}



#Control server 
module "control_server_ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  name = "control_node"
  instance_type = "t2.nano"
  key_name = aws_key_pair.this.key_name
  vpc_security_group_ids = [module.control_server_sg.vpc_security_group_id]
  subnet_id = module.vpc.public_subnets

}

#Control server  nsg 
module "control_server_sg" {
  source = "terraform-aws-modules/security-group/aws"
  name = "Control_server"
  description = "Control server NSG"
  vpc_id = module.vpc.vpc_id
  ingress_rules = ["https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr_blocks = "${local.public_ip.ip}/32"
    }
  ]
}

#AD 

#AD app registration 

