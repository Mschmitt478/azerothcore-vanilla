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
