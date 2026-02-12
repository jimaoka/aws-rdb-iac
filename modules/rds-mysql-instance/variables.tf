variable "db_identifier" {
  description = "DB instance identifier"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_class" {
  description = "Instance class (e.g. db.t4g.medium)"
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version (e.g. 8.0.35, 8.4.8)"
  type        = string
}

variable "read_replica_count" {
  description = "Number of read replicas"
  type        = number
  default     = 0
}

variable "db_parameters" {
  description = "List of DB parameters for the parameter group"
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

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, or io2)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "Provisioned IOPS (required for io1/io2, optional for gp3)"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput in MiBps (only for gp3)"
  type        = number
  default     = null
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
