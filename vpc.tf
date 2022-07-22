# #%%%%%% VPC #%%%%%%
# resource "aws_vpc" "main" {
#   cidr_block           = "10.0.0.0/16"
#   instance_tenancy     = "default"
#   enable_dns_support   = "true"
#   enable_dns_hostnames = "true"
#   enable_classiclink   = "false"
#   tags                 = merge(local.common_tags, { Name = "mainvpc", Application = "public" })
# }

# #%%%%%% Subnet #%%%%%%
# resource "aws_subnet" "mainpublic" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = "true"
#   availability_zone       = "us-east-1a"
#   tags                    = merge(local.common_tags, { Name = "mainpublic", Application = "public" })
# }
# resource "aws_subnet" "mainpublic2" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.3.0/24"
#   map_public_ip_on_launch = "true"
#   availability_zone       = "us-east-1c"
#   tags                    = merge(local.common_tags, { Name = "mainpublic", Application = "public" })
# }

# resource "aws_subnet" "mainprivate" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.2.0/24"
#   map_public_ip_on_launch = "false"
#   availability_zone       = "us-east-1b"
#   tags                    = merge(local.common_tags, { Name = "mainprivate", Application = "public" })
# }

# #%%%%%% Internet GW #%%%%%%
# resource "aws_internet_gateway" "maingw" {
#   vpc_id = aws_vpc.main.id
#   tags   = merge(local.common_tags, { Name = "maingw", Application = "public" })

# }