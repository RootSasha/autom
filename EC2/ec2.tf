provider "aws" {
  region = "eu-north-1"
}

# Перевірика існуючих ресурсів
data "aws_region" "current" {}

# Шукає образ ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] # Назва образу
  }
  owners = ["099720109477"] # ID власника 
}

# Створюється приватна VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "SpotInstanceVPC"
  }
}

# Налаштовується gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "SpotInstanceIGW"
  }
}

# Створюється таблиця маршрутизації
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

# Пов'язуєьться таблиця маршрутизацій та gw
resource "aws_route_table_association" "route_table_association" {
  subnet_id     = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

# Створюється subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SpotInstanceSubnet"
  }
}

# Налаштовуються security-groups
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

locals {
  config_file_content = file("config.txt")
}

# Створюється шаблон для інстанса
resource "aws_launch_template" "instance_template" {
  name_prefix   = "jenkins-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "key"  # Тут вказуємо ім'я вашого ключа без змінних

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

user_data = base64encode(<<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install -y git
  git clone https://github.com/RootSasha/Diplome.git /home/ubuntu/Diplome
  INSTANCE_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
  echo 'JENKINS_URL="http://'$INSTANCE_IP':8080"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'JENKINS_PASSWORD="${var.jenkins_password}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'GITHUB_TOKEN="${var.github_token}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'DOCKERHUB_PASSWORD="${var.dockerhub_password}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'AWS_ACCESS_KEY_ID="${var.aws_access_key_id}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'AWS_SECRET_ACCESS_KEY="${var.aws_secret_access_key}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  echo 'GITHUB_EMAIL="${var.github_email}"' >> /home/ubuntu/Diplome/Jenkins/config.sh
  cd /home/ubuntu/Diplome/Jenkins
  sudo bash install.sh
  sudo bash install.sh
  EOF
)
}

# Додається auto-scaling
resource "aws_autoscaling_group" "jenkins_asg" {
  desired_capacity  = 1
  max_size          = 3
  min_size          = 1
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

# Отримується інформація про інстанс
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
