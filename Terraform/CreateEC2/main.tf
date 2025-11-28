provider "aws" {
  region = "us-east-1"
}

# Get the current public IP of this machine
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Security Group to allow SSH only from this IP
resource "aws_security_group" "dev_sg" {
  name        = "dev-sg"
  description = "Allow SSH from DevOps machine"

  ingress {
    description = "SSH from DevOps machine"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]  # automatically set your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Generate SSH key for the new EC2 instance
resource "tls_private_key" "new_ec2_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "new_ec2_key" {
  key_name   = "new-ec2-key"
  public_key = tls_private_key.new_ec2_key.public_key_openssh
}

# Minimal Ubuntu EC2 instance
resource "aws_instance" "new_ec2" {
  ami               = "ami-0fa91bc90632c73c9"  # Ubuntu 22.04 LTS example
  instance_type     = "t2.micro"
  key_name          = aws_key_pair.new_ec2_key.key_name
  security_groups   = [aws_security_group.dev_sg.name]
  availability_zone = "us-east-1f"  # optional, specify AZ

  tags = {
    Name = "Terraform-Test-EC2"
  }
}

# Output private key so you can connect
output "private_key_pem" {
  value     = tls_private_key.new_ec2_key.private_key_pem
  sensitive = true
}

# Output the public IP of the new EC2
output "new_ec2_public_ip" {
  value = aws_instance.new_ec2.public_ip
}
