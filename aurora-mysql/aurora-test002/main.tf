module "aurora-test002" {
  source = "../../modules/aurora-mysql"

  cluster_identifier        = "aurora-test002"
  db_subnet_group_name      = "shared-dev-rds-db-subnet-group"
  region                    = var.aws_region
  db_cluster_instance_class = "db.t4g.medium"
  engine_version            = "8.0.mysql_aurora.3.10.3"
  read_replica_count        = 0
  deletion_protection       = false

  backup_retention_period      = 1
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = "sun:19:00-sun:20:00"
  backtrack_window             = 0

  db_parameters = []
}
