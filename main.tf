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
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "custom-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "custom-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#-------------------------------------------------------
# Network ACL
#-------------------------------------------------------

resource "aws_network_acl" "custom_nacl" {
  vpc_id     = aws_vpc.custom_vpc.id
  subnet_ids = [aws_subnet.public_subnet.id]

  tags = {
    Name = "custom-nacl"
  }
}

resource "aws_network_acl_rule" "http_inbound" {
  network_acl_id = aws_network_acl.custom_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ssh_inbound" {
  network_acl_id = aws_network_acl.custom_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "ephemeral_inbound" {
  network_acl_id = aws_network_acl.custom_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "all_outbound" {
  network_acl_id = aws_network_acl.custom_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
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
  key_name   = "assisment"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "TF_key" {
  content  = tls_private_key.rsa.private_key_openssh
  filename = "assisment"
}
resource "aws_s3_bucket" "log_bucket" {
  bucket = "my-ec2-logs-${random_id.bucket_id.hex}"
  force_destroy = true
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

# S3 Ownership Controls
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.log_bucket.id # ✅ fixed
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 Access Block
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.log_bucket.id # ✅ fixed
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.log_bucket.id # ✅ fixed
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = 7
    }
    filter {}
  }
}

# Writer EC2
resource "aws_instance" "writer_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.TF_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.writer_profile2.name
  vpc_security_group_ids = [aws_security_group.seg_as.id]

  user_data = templatefile("${path.module}/scripts/scripts.sh", {
    BUCKET_NAME = aws_s3_bucket.log_bucket.bucket
  })

  tags = {
    Name  = "Writer-Ec2"
    Stage = var.stage
  }
}


# Reader EC2
resource "aws_instance" "reader_instance" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.TF_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.reader_profile2.name
  vpc_security_group_ids = [aws_security_group.seg_as.id]

  user_data = templatefile("${path.module}/scripts/reader.sh", {
    BUCKET_NAME = aws_s3_bucket.log_bucket.bucket
  })

  tags = {
    Name  = "Reader-EC2"
    Stage = var.stage
  }
}

