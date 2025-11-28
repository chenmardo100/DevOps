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
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
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

# Upload public key to AWS with a unique name
resource "aws_key_pair" "new_ec2_key" {
  key_name   = "new-ec2-key-${timestamp()}"
  public_key = tls_private_key.new_ec2_key.public_key_openssh
}

# Save the private key locally to ~/.ssh so you can SSH
resource "local_file" "private_key_file" {
  content         = tls_private_key.new_ec2_key.private_key_pem
  filename        = "${pathexpand("~/.ssh/new-ec2-key.pem")}"
  file_permission = "0600"
}

# Minimal Ubuntu EC2 instance
resource "aws_instance" "new_ec2" {
  ami             = "ami-0fa91bc90632c73c9"  # Ubuntu 22.04 LTS
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.new_ec2_key.key_name
  security_groups = [aws_security_group.dev_sg.name]

  tags = {
    Name = "Terraform-Test-EC2"
  }
}

# Output public IP for convenience
output "new_ec2_public_ip" {
  value = aws_instance.new_ec2.public_ip
}

# Output the SSH command ready to copy/paste
output "ssh_command" {
  value = "ssh -i ~/.ssh/new-ec2-key.pem ubuntu@${aws_instance.new_ec2.public_ip}"
}

