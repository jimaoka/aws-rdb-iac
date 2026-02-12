data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/dev/vpc/vpc-id"
}

locals {
  vpc_id           = data.aws_ssm_parameter.vpc_id.value
  engine           = "aurora-mysql"
  major_minor      = join(".", slice(split(".", var.engine_version), 0, 2))
  parameter_family = "aurora-mysql${local.major_minor}"
}

resource "aws_security_group" "this" {
  name_prefix = "${var.cluster_identifier}-"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_identifier}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_parameter_group" "this" {
  name   = "${var.cluster_identifier}-cpg"
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
    Name = "${var.cluster_identifier}-cpg"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.cluster_identifier
  engine             = local.engine
  engine_version     = var.engine_version

  db_subnet_group_name            = var.db_subnet_group_name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]

  master_username             = var.master_username
  manage_master_user_password = true

  storage_encrypted        = true
  deletion_protection      = var.deletion_protection
  copy_tags_to_snapshot    = true
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final-snapshot"

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  backtrack_window             = var.backtrack_window

  tags = {
    Name = var.cluster_identifier
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = 1 + var.read_replica_count

  identifier         = "${var.cluster_identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.db_cluster_instance_class
  engine             = local.engine
  engine_version     = var.engine_version

  tags = {
    Name = "${var.cluster_identifier}-${count.index}"
  }
}
