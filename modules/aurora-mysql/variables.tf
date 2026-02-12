variable "cluster_identifier" {
  description = "Cluster identifier"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "db_cluster_instance_class" {
  description = "Instance class for cluster instances"
  type        = string
}

variable "engine_version" {
  description = "Aurora MySQL engine version (e.g. 8.0.mysql_aurora.3.04.0)"
  type        = string
}

variable "read_replica_count" {
  description = "Number of read replicas"
  type        = number
  default     = 1
}

variable "db_parameters" {
  description = "List of DB parameters for the cluster parameter group"
  type = list(object({
    name         = string
    value        = string
    apply_method = string
  }))
  default = []
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "18:00-19:00"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:19:00-sun:20:00"
}

variable "backtrack_window" {
  description = "Backtrack window in seconds (0 to disable)"
  type        = number
  default     = 0
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on destroy"
  type        = bool
  default     = false
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = true
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "admin"
}
