terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

provider "aws" {
  region=var.region
}

resource "aws_security_group" "seg_as" {
  name = "stg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "TF_key" {
  key_name   = "devops1"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "TF_key" {
  content  = tls_private_key.rsa.private_key_openssh
  filename = "devops1"
}

resource "aws_instance" "aws_dev" {
  ami = var.ami_id
  instance_type = var.instance_type
  depends_on = [aws_security_group.seg_as,
     aws_iam_instance_profile.ec2_profile,
     aws_s3_bucket.logs
  ]
  key_name = aws_key_pair.TF_key.key_name
  tags = {
     Name = "web-${var.stage}"
     Stage = var.stage
  }
  user_data = file("script.sh")
  }
