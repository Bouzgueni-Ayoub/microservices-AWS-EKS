data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "jenkings" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.public_subnet_1a.id
  associate_public_ip_address = true
  user_data                   = file("../user_data/user_data.sh")
  key_name = "key_pair"
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  security_groups = [ aws_security_group.jenkings_sg.id ]

  tags = {
    Name = "Jenkings server"
  }
}