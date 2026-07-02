resource "aws_acm_certificate" "account_portal" {
  domain_name       = var.account_portal_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-account-portal-cert"
  }
}

resource "aws_ses_domain_identity" "account_portal" {
  domain = var.account_portal_hostname
}

resource "aws_ses_domain_dkim" "account_portal" {
  domain = aws_ses_domain_identity.account_portal.domain
}

resource "aws_security_group" "account_portal_alb" {
  name        = "${var.name_prefix}-account-portal-alb-sg"
  description = "Public HTTP/HTTPS access for the Warwid account portal ALB"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To account portal origin"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-account-portal-alb-sg"
  }
}

resource "aws_lb" "account_portal" {
  name               = "${var.name_prefix}-acct"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.account_portal_alb.id]
  subnets            = data.aws_subnets.selected.ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.name_prefix}-account-portal-alb"
  }
}

resource "aws_lb_target_group" "account_portal" {
  name        = "${var.name_prefix}-acct-node"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    path                = "/api/health"
    matcher             = "200"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.name_prefix}-account-portal-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "account_portal" {
  target_group_arn = aws_lb_target_group.account_portal.arn
  target_id        = var.account_portal_origin_instance_id != null ? var.account_portal_origin_instance_id : aws_instance.azerothcore.id
  port             = 3000
}

resource "aws_lb_listener" "account_portal_http" {
  load_balancer_arn = aws_lb.account_portal.arn
  port              = 80
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

resource "aws_lb_listener" "account_portal_https" {
  count = var.account_portal_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.account_portal.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.account_portal_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account_portal.arn
  }
}

resource "aws_wafv2_web_acl" "account_portal" {
  name        = "${var.name_prefix}-account-portal"
  description = "Managed and rate-based protections for the Warwid account portal"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-by-ip"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.account_portal_waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-sensitive-account-api"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.account_portal_sensitive_api_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          regex_match_statement {
            regex_string = "^/api/(register|verify-email|login|account/(email|password|delete))$"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-sensitive-api-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-ip-reputation"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-sqli"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-account-portal-sqli"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-account-portal"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.name_prefix}-account-portal-waf"
  }
}

resource "aws_wafv2_web_acl_association" "account_portal" {
  resource_arn = aws_lb.account_portal.arn
  web_acl_arn  = aws_wafv2_web_acl.account_portal.arn
}
