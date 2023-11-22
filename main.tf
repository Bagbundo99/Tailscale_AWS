
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


#Exit node nsg
#Needs to be open for connection, can be made an script for verifying IP of the user connecting? 

#Control server 


#Control server  nsg 
module "control_server_sg" {
  source = "terraform-aws-modules/security-group/aws"
  name = "Control_server"
  description = "Control server NSG"
  vpc_id = module.vpc.default_vpc_id
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

