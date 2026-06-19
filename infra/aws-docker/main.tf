data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  count = var.vpc_id == null ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnet" "selected" {
  id = local.subnet_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  vpc_id                 = var.vpc_id == null ? data.aws_vpc.default[0].id : data.aws_vpc.selected[0].id
  subnet_id              = var.subnet_id == null ? sort(data.aws_subnets.selected.ids)[0] : var.subnet_id
  data_volume_disk_by_id = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.azerothcore_data.id, "-", "")}"
  ecr_registry           = split("/", aws_ecr_repository.azerothcore.repository_url)[0]
}

resource "aws_ecr_repository" "azerothcore" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

resource "aws_ecr_lifecycle_policy" "azerothcore" {
  repository = aws_ecr_repository.azerothcore.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecr_pull" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.azerothcore.arn]
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "${var.name_prefix}-ecr-pull"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "azerothcore" {
  name        = "${var.name_prefix}-sg"
  description = "AzerothCore auth/world access"
  vpc_id      = local.vpc_id

  ingress {
    description = "WoW authserver"
    from_port   = var.auth_port
    to_port     = var.auth_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WoW worldserver"
    from_port   = var.world_port
    to_port     = var.world_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.admin_cidrs) > 0 ? [1] : []

    content {
      description = "SSH admin"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.admin_cidrs
    }
  }

  dynamic "ingress" {
    for_each = var.enable_public_soap && length(var.admin_cidrs) > 0 ? [1] : []

    content {
      description = "AzerothCore SOAP admin"
      from_port   = var.soap_port
      to_port     = var.soap_port
      protocol    = "tcp"
      cidr_blocks = var.admin_cidrs
    }
  }

  egress {
    description = "Outbound internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

resource "aws_ebs_volume" "azerothcore_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size_gb
  type              = var.data_volume_type
  encrypted         = true

  tags = {
    Name   = "${var.name_prefix}-data"
    Backup = var.enable_ebs_snapshots ? "daily" : "disabled"
  }
}

resource "aws_instance" "azerothcore" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.azerothcore.id]
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region              = var.aws_region
    auth_port               = var.auth_port
    data_volume_device      = local.data_volume_disk_by_id
    db_external_port        = var.db_external_port
    db_root_password        = var.db_root_password == null ? "" : var.db_root_password
    ecr_registry            = local.ecr_registry
    ecr_repository_url      = aws_ecr_repository.azerothcore.repository_url
    enable_mysql_backups    = var.enable_mysql_backups
    enable_public_soap      = var.enable_public_soap
    image_pull_wait_minutes = var.image_pull_wait_minutes
    image_tag               = var.image_tag
    mysql_backup_hour_utc   = var.mysql_backup_hour_utc
    realm_address           = var.realm_address
    realm_name              = var.realm_name
    soap_port               = var.soap_port
    swap_size_gb            = var.swap_size_gb
    world_port              = var.world_port
  })

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.name_prefix}-server"
  }
}

resource "aws_volume_attachment" "azerothcore_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.azerothcore_data.id
  instance_id = aws_instance.azerothcore.id
}

resource "aws_eip" "azerothcore" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-eip"
  }
}

resource "aws_eip_association" "azerothcore" {
  allocation_id = aws_eip.azerothcore.id
  instance_id   = aws_instance.azerothcore.id
}

data "aws_iam_policy_document" "dlm_assume_role" {
  count = var.enable_ebs_snapshots ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  count              = var.enable_ebs_snapshots ? 1 : 0
  name               = "${var.name_prefix}-dlm-role"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count      = var.enable_ebs_snapshots ? 1 : 0
  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "azerothcore_data" {
  count              = var.enable_ebs_snapshots ? 1 : 0
  description        = "Daily snapshots for ${var.name_prefix} data volume"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = {
      Name = "${var.name_prefix}-data"
    }

    schedule {
      name = "daily"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.snapshot_time_utc]
      }

      retain_rule {
        count = var.snapshot_retention_count
      }

      copy_tags = true
    }
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}
