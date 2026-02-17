module "rds-instance-test001" {
  source = "../../modules/rds-mysql-instance"

  db_identifier        = "rds-instance-test001"
  db_subnet_group_name = "shared-dev-rds-db-subnet-group"
  region               = var.aws_region
  instance_class       = "db.t4g.medium"
  engine_version       = "8.4.8"
  read_replica_count   = 1
  deletion_protection  = false

  storage_type      = "gp2"
  allocated_storage = 20

  backup_retention_period      = 1
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = "sun:19:00-sun:20:00"

  db_parameters = []
}
