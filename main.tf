#%%%%%% locals #%%%%%%
locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Service     = "Elite Technology Services"
    Owner       = "EliteInfra"
    Department  = "IT"
    Company     = "EliteSolutions LLC"
    ManagedWith = "Terraform"
    Casecode    = "es20"
  }
  # network tags to be assigned to all resources
  network = {
    Service     = "Elite Technology Services"
    Owner       = "EliteInfra"
    Department  = "IT"
    Company     = "EliteSolutions LLC"
    ManagedWith = "Terraform"
    Casecode    = "es20"
  }
  # application tags to be assigned to all resources
  application = {
    app_name = "publicapp"
    location = "us-east-2"
    alias    = "Dev"
    ec2      = "public"
  }
  instance_type = "t2.micro"
}

#%%%%%% server #%%%%%%
resource "aws_instance" "simpleserver" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  subnet_id              = aws_subnet.mainpublic.id
  key_name               = aws_key_pair.mykeypair.key_name
  vpc_security_group_ids = [aws_security_group.simpleserver.id]

  #   provisioner "remote-exec" {
  #     inline = [
  #       "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u {var.user} -i '${self.public_ip},' --private-key ${var.ssh_private_key} playbook.yml"
  #     ]
  #   }
  provisioner "file" {
    source      = "./templates/script.tpl"
    destination = "/tmp/script.sh"
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.user} -i '${self.public_ip},' --private-key ${var.ssh_private_key} playbook.yml -v"
  }
  connection {
    user        = var.user
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    private_key = file(var.ssh_private_key)
  }
  tags = merge(local.common_tags, { Name = "simple-server", Application = "public" })
}

resource "aws_key_pair" "mykeypair" {
  key_name   = "simpleserverkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvTdfcR/qCrnoEkcsW0XNoRiMf9fEWtIg0EN6HS3ND4QWE2GTCuIqmxAtYLPek0u++BwNpRfTSBhqVXHbv0ccWyG5uCOxiauZsAfn5PN66mCbc7aWQXIQuEqT+25xg88SzuA2nPwg2byf6l+kH3VSZv8TY5V4xrIvOnksBDvHtulblSRm7UdmNqtVIkoMXV1eGiasyvkwqg6WSqvVkW5aAhmvCcTDLzwf9Gjif8cIXejgzQnYj7CFC/0tCZ5jEewXIrrppuaVtsed+o/0NpHzq/SY8y7E0MrNw5NarxNa+5RwTiNSOEPC0n+VIrohgr6XkAUn4LwRKhIanPWvfYC6bPgd5sS737LJAGNe8QqX9K/0Bqq7H3RS/M0mQ/qLFcpLxX/8E4ecSPYfar7LJOOu6JELlexmOuNMDXZMfcOScMr9hByvqHx257rZdt68UGJh+Hz9ql8grgarAYlVqtQF8gtEfagf9zdFMSlTCXUNRleLj5QWgRYqUlZjdGCkwVEM= lbena@LAPTOP-QB0DU4OG"
}


#%%%%%% VPC #%%%%%%
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  tags                 = merge(local.common_tags, { Name = "mainvpc", Application = "public" })
}

#%%%%%% Subnet #%%%%%%
resource "aws_subnet" "mainpublic" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"
  tags                    = merge(local.common_tags, { Name = "mainpublic", Application = "public" })
}

resource "aws_subnet" "mainprivate" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "us-east-1b"
  tags                    = merge(local.common_tags, { Name = "mainprivate", Application = "public" })
}

#%%%%%% Internet GW #%%%%%%
resource "aws_internet_gateway" "maingw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "maingw", Application = "public" })

}

#%%%%%% route tables #%%%%%%
resource "aws_route_table" "mainpublicrt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.maingw.id
  }
  tags = merge(local.common_tags, { Name = "mainpublicrt", Application = "public" })
}

#%%%%%% route associations public #%%%%%%
resource "aws_route_table_association" "mainpublic" {
  subnet_id      = aws_subnet.mainpublic.id
  route_table_id = aws_route_table.mainpublicrt.id
}

#%%%%%% Security Groups #%%%%%%
resource "aws_security_group" "simpleserver" {
  vpc_id      = aws_vpc.main.id
  name        = "public web allow"
  description = "security group for ubuntuserver"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["70.114.65.185/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "simpleservergroup" })
}

#%%%%%% output #%%%%%%
output "publicip" {
  value = aws_instance.simpleserver.public_ip
}

#%%%%%% data lookup #%%%%%%
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "cloudinit_config" "hostip" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    filename     = "scripts"
    content = templatefile("./templates/script.tpl",
      {
        hostip = aws_instance.simpleserver.public_ip
    })
  }
}

#%%%%%% variables #%%%%%%
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = "default"
}

variable "ssh_private_key" {
  type    = string
  default = "/home/devopslab/.ssh/simpleserverkey"
}

variable "user" {
  type    = string
  default = "ubuntu"
}

variable "path" {
  type    = string
  default = "/root/.ssh/known_hosts"
}