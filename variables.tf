variable "access_key" {
    default = "ACCESS_KEY_HERE"
}
variable "secret_key" {
	default = "SECRET_KEY_HERE"
}
variable "region" {
  default = "ca-central-1"
}
variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default = "192.168.0.0/24"
}
variable "cidr_subnet_public_a" {
  description = "CIDR block for the subnet"
  default = "192.168.0.63/26"
}

variable "cidr_subnet_public_b" {
  description = "CIDR block for the subnet"
  default = "192.168.0.127/26"
}

variable "cidr_subnet_private_a" {
  description = "CIDR block for the subnet"
  default = "192.168.0.191/26"
}

variable "cidr_subnet_private_b" {
  description = "CIDR block for the subnet"
  default = "192.168.0.255/26"
}

variable "availability_zone" {
  description = "availability zone to create subnet"
  default = "ca-central-1"
}
variable "public_key_path" {
  description = "Public key path"
  default = "~/.ssh/id_rsa.pub"
}
variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default = "ami-0cf31d971a3ca20d6"
}
variable "instance_type" {
  description = "type for aws EC2 instance"
  default = "t2.micro"
}
variable "environment_tag" {
  description = "Environment tag"
  default = "Production"
}