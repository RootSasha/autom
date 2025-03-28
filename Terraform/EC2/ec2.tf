provider "aws" {
  region = "eu-north-1"
}

data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Офіційний власник Ubuntu AMI
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "SpotInstanceVPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "SpotInstanceIGW"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "SpotInstanceRouteTable"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SpotInstanceSubnet"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "JENKINS"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "BEK"
    from_port   = 5034
    to_port     = 5034
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FRONTEND"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "BAZA"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "GRAFANA"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
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

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_launch_template" "instance_template" {
  name_prefix   = "jenkins-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "key" # Замініть на ваш ключ

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_ssh.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 50
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "JenkinsInstance"
    }
  }
}

resource "aws_autoscaling_group" "jenkins_asg" {
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.main.id]

  launch_template {
    id      = aws_launch_template.instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "JenkinsAutoScaled"
    propagate_at_launch = true
  }
}

data "aws_instances" "jenkins" {
  filter {
    name   = "tag:Name"
    values = ["JenkinsAutoScaled"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

output "public_ip" {
  description = "Public IP of the first running Jenkins instance"
  value       = length(data.aws_instances.jenkins.ids) > 0 ? element(data.aws_instances.jenkins.public_ips, 0) : "No instances found"
}