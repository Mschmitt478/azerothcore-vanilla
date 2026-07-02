variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile name for local Terraform runs."
  type        = string
  default     = null
}

variable "project_tag_value" {
  description = "Default Project tag value applied through the AWS provider."
  type        = string
  default     = "warwid-azerothcore"
}

variable "name_prefix" {
  description = "Prefix used for AWS resource names."
  type        = string
  default     = "warwid-azerothcore"
}

variable "instance_type" {
  description = "EC2 instance type. AzerothCore Docker builds are CPU/RAM heavy; t3.large is a practical small starting point."
  type        = string
  default     = "t3.large"
}

variable "ami_id" {
  description = "Optional fixed AMI ID for the EC2 host. Set this after deployment to avoid replacing the server when the latest Ubuntu AMI changes."
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name for SSH. Leave null to launch without an EC2 key pair."
  type        = string
  default     = null
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to SSH and use restricted admin ports. Example: [\"203.0.113.10/32\"]."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC ID. Leave null to use the default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID. Leave null to use the first subnet in the selected/default VPC."
  type        = string
  default     = null
}

variable "root_volume_size_gb" {
  description = "Root volume size for OS, Docker layers, and build scratch space."
  type        = number
  default     = 50
}

variable "data_volume_size_gb" {
  description = "Persistent EBS data volume size for MySQL, client data, logs, backups, and repo checkout."
  type        = number
  default     = 100
}

variable "data_volume_type" {
  description = "Persistent EBS data volume type."
  type        = string
  default     = "gp3"
}

variable "swap_size_gb" {
  description = "Swap file size created on the persistent volume before the Docker runtime starts."
  type        = number
  default     = 6
}

variable "ecr_repository_name" {
  description = "ECR repository used for AzerothCore runtime images."
  type        = string
  default     = "warwid-azerothcore"
}

variable "image_tag" {
  description = "Image tag prefix pulled by EC2. Images are expected as <image_tag>-authserver, <image_tag>-worldserver, <image_tag>-db-import, and <image_tag>-client-data."
  type        = string
  default     = "master"
}

variable "image_pull_wait_minutes" {
  description = "How long cloud-init waits for ECR images to appear after the instance starts."
  type        = number
  default     = 180
}

variable "realm_name" {
  description = "Realm name written to the auth realmlist table."
  type        = string
  default     = "Warwid"
}

variable "realm_address" {
  description = "Public realm address written to the auth realmlist table and used in client realmlist.wtf."
  type        = string
  default     = "play.warwid.com"
}

variable "account_portal_hostname" {
  description = "Public hostname for the Warwid account portal."
  type        = string
  default     = "accounts.warwid.com"
}

variable "dns_zone_name" {
  description = "Public DNS zone to prepare in Route 53. Delegation is manual at the registrar."
  type        = string
  default     = "warwid.com"
}

variable "account_portal_certificate_arn" {
  description = "Issued ACM certificate ARN for the account portal ALB HTTPS listener. Leave null until DNS validation has issued the certificate."
  type        = string
  default     = null
}

variable "account_portal_origin_instance_id" {
  description = "Existing EC2 instance ID that serves the account portal origin. Set this to avoid pulling the mutable aws_instance resource into targeted edge plans."
  type        = string
  default     = null
}

variable "account_portal_waf_rate_limit" {
  description = "Five-minute per-IP AWS WAF rate limit for the account portal."
  type        = number
  default     = 500
}

variable "account_portal_sensitive_api_rate_limit" {
  description = "Five-minute per-IP AWS WAF rate limit for sensitive account API paths."
  type        = number
  default     = 50
}

variable "auth_port" {
  description = "AzerothCore authserver TCP port."
  type        = number
  default     = 3724
}

variable "world_port" {
  description = "AzerothCore worldserver TCP port."
  type        = number
  default     = 8085
}

variable "soap_port" {
  description = "AzerothCore SOAP TCP port. It is bound to localhost on the host unless enable_public_soap is true."
  type        = number
  default     = 7878
}

variable "db_external_port" {
  description = "Host MySQL port bound to localhost for SSH tunneling and maintenance."
  type        = number
  default     = 3306
}

variable "enable_public_soap" {
  description = "Expose SOAP to admin_cidrs. Keep false unless you know you need it."
  type        = bool
  default     = false
}

variable "enable_ebs_snapshots" {
  description = "Create an AWS DLM policy for daily snapshots of the AzerothCore data volume."
  type        = bool
  default     = true
}

variable "snapshot_time_utc" {
  description = "UTC time for daily EBS snapshots in HH:MM format."
  type        = string
  default     = "08:00"
}

variable "snapshot_retention_count" {
  description = "Number of daily EBS snapshots to retain."
  type        = number
  default     = 7
}

variable "enable_mysql_backups" {
  description = "Install a daily local MySQL dump timer on the EC2 host."
  type        = bool
  default     = true
}

variable "mysql_backup_hour_utc" {
  description = "UTC hour for the local MySQL dump timer."
  type        = number
  default     = 7

  validation {
    condition     = var.mysql_backup_hour_utc >= 0 && var.mysql_backup_hour_utc <= 23
    error_message = "mysql_backup_hour_utc must be between 0 and 23."
  }
}

variable "db_root_password" {
  description = "Optional MySQL root password. Leave null to generate it on the EC2 host instead of storing it in Terraform state."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Additional tags for AWS resources."
  type        = map(string)
  default     = {}
}
