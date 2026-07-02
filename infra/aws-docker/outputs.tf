output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.azerothcore.id
}

output "public_ip" {
  description = "Elastic public IP for the AzerothCore server."
  value       = aws_eip.azerothcore.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for AzerothCore images."
  value       = aws_ecr_repository.azerothcore.repository_url
}

output "expected_image_tags" {
  description = "Image tags the EC2 bootstrap pulls from ECR."
  value = [
    "${var.image_tag}-authserver",
    "${var.image_tag}-worldserver",
    "${var.image_tag}-db-import",
    "${var.image_tag}-client-data",
  ]
}

output "realm_address" {
  description = "Realm address written into acore_auth.realmlist."
  value       = var.realm_address
}

output "squarespace_dns_record" {
  description = "Create this A record in Squarespace DNS."
  value       = "${var.realm_address} A ${aws_eip.azerothcore.public_ip}"
}

output "client_realmlist" {
  description = "Client realmlist.wtf value."
  value       = "set realmlist ${var.realm_address}"
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID prepared for future warwid.com delegation."
  value       = aws_route53_zone.warwid.zone_id
}

output "route53_nameservers" {
  description = "Nameservers to set at the registrar when switching warwid.com DNS authority to Route 53."
  value       = aws_route53_zone.warwid.name_servers
}

output "route53_future_account_portal_record" {
  description = "Record to create in Route 53 for the WAF-protected account portal after DNS authority moves."
  value       = "${var.account_portal_hostname} CNAME ${aws_lb.account_portal.dns_name}"
}

output "route53_future_realm_record" {
  description = "Record to create in Route 53 for the game realm after DNS authority moves."
  value       = "${var.realm_address} A ${aws_eip.azerothcore.public_ip}"
}

output "ssh_command" {
  description = "SSH command, if you configured an EC2 key pair."
  value       = var.ssh_key_name == null ? null : "ssh ubuntu@${aws_eip.azerothcore.public_ip}"
}

output "status_commands" {
  description = "Useful commands to run on the EC2 host."
  value = [
    "sudo cloud-init status --long",
    "cd /srv/azerothcore/runtime && sudo docker compose ps",
    "cd /srv/azerothcore/runtime && sudo docker compose logs -f ac-db-import ac-authserver ac-worldserver",
    "sudo cat /srv/azerothcore/secrets/db-root-password",
  ]
}

output "data_volume_id" {
  description = "Persistent EBS volume ID containing AzerothCore data."
  value       = aws_ebs_volume.azerothcore_data.id
}

output "snapshot_policy_id" {
  description = "AWS DLM snapshot policy ID, if daily snapshots are enabled."
  value       = var.enable_ebs_snapshots ? aws_dlm_lifecycle_policy.azerothcore_data[0].id : null
}

output "account_portal_acm_certificate_arn" {
  description = "ACM certificate ARN for the account portal. Use this as account_portal_certificate_arn after DNS validation has issued the certificate."
  value       = aws_acm_certificate.account_portal.arn
}

output "account_portal_acm_dns_validation_records" {
  description = "DNS records required to validate the account portal ACM certificate."
  value = [
    for option in aws_acm_certificate.account_portal.domain_validation_options : {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  ]
}

output "account_portal_ses_domain_verification_record" {
  description = "TXT record required to verify the account portal domain in SES."
  value = {
    name  = "_amazonses.${aws_ses_domain_identity.account_portal.domain}"
    type  = "TXT"
    value = aws_ses_domain_identity.account_portal.verification_token
  }
}

output "account_portal_ses_dkim_records" {
  description = "CNAME records required for SES DKIM."
  value = [
    for token in aws_ses_domain_dkim.account_portal.dkim_tokens : {
      name  = "${token}._domainkey.${aws_ses_domain_identity.account_portal.domain}"
      type  = "CNAME"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}

output "account_portal_alb_dns_name" {
  description = "DNS name for the account portal ALB. Point accounts.warwid.com here after ACM validation and HTTPS listener activation."
  value       = aws_lb.account_portal.dns_name
}

output "account_portal_waf_acl_arn" {
  description = "AWS WAF web ACL attached to the account portal ALB."
  value       = aws_wafv2_web_acl.account_portal.arn
}
