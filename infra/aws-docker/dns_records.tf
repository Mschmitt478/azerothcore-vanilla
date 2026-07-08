resource "aws_route53_record" "zone_apex" {
  zone_id = aws_route53_zone.warwid.zone_id
  name    = var.dns_zone_name
  type    = "A"
  ttl     = var.dns_record_ttl_seconds
  records = var.dns_zone_apex_a_records
}

resource "aws_route53_record" "www" {
  count = var.dns_www_cname == null ? 0 : 1

  zone_id = aws_route53_zone.warwid.zone_id
  name    = "www.${var.dns_zone_name}"
  type    = "CNAME"
  ttl     = var.dns_record_ttl_seconds
  records = [var.dns_www_cname]
}

resource "aws_route53_record" "realm" {
  zone_id = aws_route53_zone.warwid.zone_id
  name    = var.realm_address
  type    = "A"
  ttl     = var.dns_record_ttl_seconds
  records = [aws_eip.azerothcore.public_ip]
}

resource "aws_route53_record" "account_portal" {
  zone_id = aws_route53_zone.warwid.zone_id
  name    = var.account_portal_hostname
  type    = "CNAME"
  ttl     = var.dns_record_ttl_seconds
  records = [aws_lb.account_portal.dns_name]
}

resource "aws_route53_record" "account_portal_acm_validation" {
  for_each = {
    for option in aws_acm_certificate.account_portal.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      type   = option.resource_record_type
      record = option.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.warwid.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = var.dns_record_ttl_seconds
  records         = [each.value.record]
}

resource "aws_route53_record" "account_portal_ses_verification" {
  allow_overwrite = true
  zone_id         = aws_route53_zone.warwid.zone_id
  name            = "_amazonses.${aws_ses_domain_identity.account_portal.domain}"
  type            = "TXT"
  ttl             = var.dns_record_ttl_seconds
  records         = [aws_ses_domain_identity.account_portal.verification_token]
}

resource "aws_route53_record" "account_portal_ses_dkim" {
  for_each = toset(aws_ses_domain_dkim.account_portal.dkim_tokens)

  allow_overwrite = true
  zone_id         = aws_route53_zone.warwid.zone_id
  name            = "${each.value}._domainkey.${aws_ses_domain_identity.account_portal.domain}"
  type            = "CNAME"
  ttl             = var.dns_record_ttl_seconds
  records         = ["${each.value}.dkim.amazonses.com"]
}
