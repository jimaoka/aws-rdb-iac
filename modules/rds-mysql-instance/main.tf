data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/dev/vpc/vpc-id"
}

locals {
  vpc_id               = data.aws_ssm_parameter.vpc_id.value
  engine               = "mysql"
  major_minor          = join(".", slice(split(".", var.engine_version), 0, 2))
  parameter_family     = "mysql${local.major_minor}"
  use_managed_password = var.read_replica_count == 0
}

resource "aws_security_group" "this" {
  name_prefix = "${var.db_identifier}-"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.db_identifier}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.db_identifier}-pg"
  family = local.parameter_family

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = {
    Name = "${var.db_identifier}-pg"
  }
}

resource "random_password" "master" {
  count   = local.use_managed_password ? 0 : 1
  length  = 32
  special = false
}

resource "aws_db_instance" "this" {
  identifier     = var.db_identifier
  engine         = local.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  multi_az       = true

  allocated_storage  = var.allocated_storage
  storage_type       = var.storage_type
  iops               = var.iops
  storage_throughput = var.storage_throughput

  db_subnet_group_name   = var.db_subnet_group_name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  username                    = var.master_username
  manage_master_user_password = local.use_managed_password ? true : null
  password                    = local.use_managed_password ? null : random_password.master[0].result

  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_identifier}-final-snapshot"

  backup_retention_period = var.backup_retention_period
  backup_window           = var.preferred_backup_window
  maintenance_window      = var.preferred_maintenance_window

  tags = {
    Name = var.db_identifier
  }
}

resource "aws_db_instance" "read_replica" {
  count = var.read_replica_count

  identifier          = "${var.db_identifier}-replica-${count.index}"
  replicate_source_db = aws_db_instance.this.identifier
  instance_class      = var.instance_class

  storage_encrypted      = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.this.id]

  tags = {
    Name = "${var.db_identifier}-replica-${count.index}"
  }
}
