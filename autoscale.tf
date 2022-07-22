# resource "aws_key_pair" "simpleserverkey" {
#   key_name   = "simpleserverkey"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDHhQOAaTjgDg3Tfupm9pwLFbjo/uhHU5Ll44Qdf7wGmHKbvTT/LS5v0AxeDP7aJQsCnd8EK8m+hnNddy7kxDjCOxT5FlIrvK/bgp2pin2luMGGL5NVw1MFRW3B+hAdr+lhxi4YX4LvcaMe6zA++huRLu4xazHEKiOs0xSwISqDI66IntVMv+1OOpv0WZZLP2cuTFIeoBSvPuY5XPweemh9GSv52wxaNjo2KzvDtjVCuCHTE4fQwddH4gokJ2JrBZNTulIqQ5n1ML7j2AXxEa5gZwF30zgTtOZ0ovE/noyoCWwKUw5U7K8J2j4E2TD6/QtvCWvZ48sM/foexxZKZaVTAxPLCFmUxlWCyDa5Wg6b6NWA3Ww/ZDJOgnmo77pbcvOIPNafnZmFnTbQFIgUJ30g3depJ0PMkYcmByAMaFRQPPebctog5DoiSTJdZ12phOE/aew4VW4Jhiy1spfc3fc3IJaaBigaCM8ICSybEEiQSqO4Wc3zAJ8IpirpaNVxhDU= lbena@LAPTOP-QB0DU4OG"
#   lifecycle {
#     ignore_changes = [public_key]
#   }
# }

# resource "aws_launch_configuration" "simpleserverlaunchconfig" {
#   name_prefix     = "simpleserverlaunchconfig"
#   image_id        = var.AMIS[var.AWS_REGION]
#   instance_type   = "t2.micro"
#   key_name        = aws_key_pair.simpleserverkey.key_name
#   security_groups = [aws_security_group.server-sg.id]

#   root_block_device {
#     volume_size = 155
#     volume_type = "gp2"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }

#     provisioner "file" {
#       source      = "./scripts/script.sh"
#       destination = "/tmp/script.sh"
#     }
#     provisioner "local-exec" {
#       command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.user} -i '${var.host},' --private-key ${var.ssh_private_key} playbook-nginx.yml -vv"
#     }
#     connection {
#       user        = var.user
#     #This object has no argument, nested block, or exported attribute named "public_ip". doesn't work for autoscale
#       host        = var.host #(self.associate_public_ip_address)
#       type        = "ssh"
#       private_key = file(var.ssh_private_key)
#     }
# }

# resource "aws_autoscaling_group" "simpleserverautoscaling" {
#   name                      = "simpleserverautoscaling"
#   vpc_zone_identifier       = [aws_subnet.mainpublic.id, aws_subnet.mainpublic2.id]
#   launch_configuration      = aws_launch_configuration.simpleserverlaunchconfig.name
#   target_group_arns         = [aws_lb_target_group.cloudreachwork_80.arn]
#   min_size                  = 1
#   max_size                  = 1
#   health_check_grace_period = 300
#   health_check_type         = "ELB"
#   force_delete              = true


#   tag {
#     key                 = "Name"
#     value               = "simpleserverinstance"
#     propagate_at_launch = true
#   }
# }

# ################################################
# # Load Balancing
# ################################################
# resource "aws_lb" "cloudreachwork_lb" {
#   name               = "cloudreachwork-${var.app_tier}"
#   internal           = false
#   load_balancer_type = "application"

#   security_groups = [
#     aws_security_group.server-sg.id,
#     aws_security_group.alb.id
#   ]

#   subnets = [aws_subnet.mainpublic.id, aws_subnet.mainpublic2.id]
#   tags    = merge({ Name = "cloudreachwork-${var.app_tier}" }, local.common_tags)
# }

# resource "aws_lb_target_group" "cloudreachwork_80" {
#   name     = "cloudreachwork-80-${var.app_tier}"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id

#   health_check {
#     path                = "/_health_check"
#     protocol            = "HTTPS"
#     matcher             = 200
#     healthy_threshold   = 5
#     unhealthy_threshold = 3
#     timeout             = 10
#     interval            = 30
#   }

#   tags = merge(
#     { Name = "cloudreachwork-80-${var.app_tier}" },
#     { Description = "ALB Target Group for web application HTTPS traffic" },
#     local.common_tags
#   )
# }

# resource "aws_lb_listener" "cloureach_443" {
#   load_balancer_arn = aws_lb.cloudreachwork_lb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.cloudreach_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.cloudreachwork_80.arn
#   }
# }

# resource "aws_lb_listener" "cloureach_80_rd" {
#   load_balancer_arn = aws_lb.cloudreachwork_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = 443
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

# #####------ Certificate -----------####
# resource "aws_acm_certificate" "cloudreach_cert" {
#   domain_name       = "*.elitelabtools.com"
#   validation_method = "DNS"
#   lifecycle {
#     create_before_destroy = true
#   }
#   tags = merge(local.common_tags,
#     { Name = "cloudreachserver.elitelabtools.com"
#   Cert = "cloureach" })
# }

# ###------- Cert Validation -------###
# ###-------------------------------###
# data "aws_route53_zone" "primary" {
#   name = "elitelabtools.com"
# }
# resource "aws_route53_record" "cloudreach_record" {
#   for_each = {
#     for dvo in aws_acm_certificate.cloudreach_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.primary.zone_id
# }

# resource "aws_acm_certificate_validation" "cloudreach_cert" {
#   certificate_arn         = aws_acm_certificate.cloudreach_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cloudreach_record : record.fqdn]
# }

# # ##------- ALB Alias record ----------##
# ###-----------------------------------###
# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.primary.zone_id
#   name    = "cloudreachserver.elitelabtools.com"
#   type    = "A"

#   alias {
#     name                   = aws_lb.cloudreachwork_lb.dns_name
#     zone_id                = aws_lb.cloudreachwork_lb.zone_id
#     evaluate_target_health = true
#   }
# }


# #################################################################
# ############## SG ##############################################


# /////sg
# resource "aws_security_group" "server-sg" {
#   vpc_id      = aws_vpc.main.id
#   name        = "server-sg"
#   description = "security group that allows ssh and all egress traffic"
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["70.114.65.185/32"]
#   }

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb.id]
#   }
#   tags = {
#     Name = "server-sg"
#   }
# }

# resource "aws_security_group" "alb" {
#   vpc_id      = aws_vpc.main.id
#   name        = "alb"
#   description = "security group that allows alb traffic"
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "alb-sg"
#   }
# }