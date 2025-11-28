##############################
# AWS PROVIDER
##############################
provider "aws" {
  region = "us-east-1"
}

##############################
# GET YOUR PUBLIC IP
##############################
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

##############################
# SECURITY GROUP (SSH ONLY FROM YOUR IP)
##############################
resource "aws_security_group" "dev_sg" {
  name        = "dev-sg"
  description = "Allow SSH only from DevOps machine"

  ingress {
    description = "SSH from DevOps machine"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Fixed deprecated attribute
    cidr_blocks = [
      format("%s/32", chomp(data.http.my_ip.response_body))
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##############################
# GENERATE SSH KEYPAIR FOR THE NEW EC2
##############################
resource "tls_private_key" "new_ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save private key locally so you can SSH manually
resource "local_file" "private_key" {
  content         = tls_private_key.new_ec2_key.private_key_pem
  filename        = "${pathexpand("~/.ssh/my-new-key")}"
  file_permission = "0600"
}

# Save public key locally (optional)
resource "local_file" "public_key" {
  content         = tls_private_key.new_ec2_key.public_key_openssh
  filename        = "${pathexpand("~/.ssh/my-new-key.pub")}"
  file_permission = "0644"
}

# AWS key pair
resource "aws_key_pair" "new_ec2_key" {
  key_name   = "new-ec2-key"
  public_key = tls_private_key.new_ec2_key.public_key_openssh
}

##############################
# EC2 INSTANCE
##############################
resource "aws_instance" "new_ec2" {
  ami               = "ami-04b70fa74e45c3917"   # Ubuntu 22.04
  instance_type     = "t3.micro"
  key_name          = aws_key_pair.new_ec2_key.key_name
  security_groups   = [aws_security_group.dev_sg.name]
  availability_zone = "us-east-1f"

  tags = {
    Name = "Terraform-Test-EC2"
  }
}

##############################
# OUTPUTS
##############################
# Path to the private key (manual SSH)
output "private_key_path" {
  description = "Path to the private key to SSH into the new EC2"
  value       = "~/.ssh/my-new-key"
}

# Public IP of the new EC2
output "new_ec2_public_ip" {
  value = aws_instance.new_ec2.public_ip
}
