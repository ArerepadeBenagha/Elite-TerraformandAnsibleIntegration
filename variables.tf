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

# variable "hostip" {
#   type    = string
#   default = data.aws_instance.publicip.public_ip
# }