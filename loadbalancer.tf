###-------- ALB -------###
resource "aws_lb" "simpleserverlb" {
  name               = join("-", [local.application.app_name, "simpleserverlb"])
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.main-alb.id]
  subnets            = [aws_subnet.mainpublic.id, aws_subnet.mainpublic2.id]
  idle_timeout       = "60"

  access_logs {
    bucket  = aws_s3_bucket.logs_s3dev.bucket
    prefix  = join("-", [local.application.app_name, "simpleserverlbs3logs"])
    enabled = true
  }
  tags = merge(local.common_tags,
    { Name = "simpleserver"
  Application = "public" })
}

///////////////
# resource "aws_wafv2_web_acl_association" "example" {
#   resource_arn = aws_lb.simpleserverlb.arn
#   web_acl_arn  = aws_wafv2_web_acl.test.arn
# }

###------- ALB Health Check -------###
resource "aws_lb_target_group" "simpleserverapp_tglb" {
  name     = join("-", [local.application.app_name, "simpleserverapptglb"])
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    timeout             = "5"
    interval            = "30"
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "simpleserverapp_tglbat" {
  target_group_arn = aws_lb_target_group.simpleserverapp_tglb.arn
  target_id        = aws_instance.simpleserver.id
  port             = 80
}

####-------- SSL Cert ------#####
resource "aws_lb_listener" "simpleserverapp_lblist2" {
  load_balancer_arn = aws_lb.simpleserverlb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.simpleservercert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.simpleserverapp_tglb.arn
  }
}
####---- Redirect Rule -----####
resource "aws_lb_listener" "simpleserverapp_lblist" {
  load_balancer_arn = aws_lb.simpleserverlb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

########------- S3 Bucket -----------####
resource "aws_s3_bucket" "logs_s3dev" {
  bucket = join("-", [local.application.app_name, "logdev"])
  acl    = "private"

  tags = merge(local.common_tags,
    { Name = "simpleserver"
  bucket = "private" })
}
resource "aws_s3_bucket_policy" "logs_s3dev" {
  bucket = aws_s3_bucket.logs_s3dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "MYBUCKETPOLICY"
    Statement = [
      {
        Sid       = "Allow"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs_s3dev.arn,
          "${aws_s3_bucket.logs_s3dev.arn}/*",
        ]
        Condition = {
          NotIpAddress = {
            "aws:SourceIp" = "8.8.8.8/32"
          }
        }
      },
    ]
  })
}

#IAM
resource "aws_iam_role" "simpleserver_role" {
  name = join("-", [local.application.app_name, "simpleserverrole"])

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(local.common_tags,
    { Name = "simpleserver"
  Role = "simpleserverrole" })
}

#######------- IAM Role ------######
resource "aws_iam_role_policy" "simpleserver_policy" {
  name = join("-", [local.application.app_name, "simpleserverpolicy"])
  role = aws_iam_role.simpleserver_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

#####------ Certificate -----------####
resource "aws_acm_certificate" "simpleservercert" {
  domain_name       = "*.elitelabtools.com"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(local.common_tags,
    { Name = "simpleapp.elitelabtools.com"
  Cert = "simpleservercert" })
}

###------- Cert Validation -------###
data "aws_route53_zone" "main-zone" {
  name         = "elitelabtools.com"
  private_zone = false
}

resource "aws_route53_record" "simpleserver_record" {
  for_each = {
    for dvo in aws_acm_certificate.simpleservercert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main-zone.zone_id
}

resource "aws_acm_certificate_validation" "simpleservercert" {
  certificate_arn         = aws_acm_certificate.simpleservercert.arn
  validation_record_fqdns = [for record in aws_route53_record.simpleserver_record : record.fqdn]
}

##------- ALB Alias record ----------##
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main-zone.zone_id
  name    = "simpleapp.elitelabtools.com"
  type    = "A"

  alias {
    name                   = aws_lb.simpleserverlb.dns_name
    zone_id                = aws_lb.simpleserverlb.zone_id
    evaluate_target_health = true
  }
}