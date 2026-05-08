variable "name_prefix" {
  description = "Prefix used to name RDS resources, e.g. tasktreat-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database lives in. Used to scope the RDS security group."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group. Must span at least 2 AZs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS requires at least two subnets across distinct availability zones."
  }
}

variable "allowed_security_groups" {
  description = "Security groups allowed to connect to PostgreSQL on port 5432. Map of static label -> security group ID. Static keys are required because the actual SG IDs (e.g. the EKS cluster SG) are only known after apply, and Terraform needs for_each keys at plan time."
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  description = "PostgreSQL engine version. Must be a version AWS still offers in your region (run `aws rds describe-db-engine-versions --engine postgres --region <region>` to list valid values; old patches get retired)."
  type        = string
  default     = "16.13"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage_gb" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling in GB. Set equal to allocated_storage_gb to disable autoscaling."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name created by RDS."
  type        = string
  default     = "tasktreat"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
}

variable "db_password" {
  description = "Master DB password. Pass via TF_VAR_db_password or an untracked tfvars file."
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "PostgreSQL listening port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Whether to deploy the DB in multiple AZs. Disabled in dev for cost."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the DB is publicly reachable. MUST be false."
  type        = bool
  default     = false

  validation {
    condition     = var.publicly_accessible == false
    error_message = "publicly_accessible must remain false; the database must stay private."
  }
}

variable "backup_retention_period" {
  description = "Days to retain automated backups."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "If true, the DB cannot be destroyed via Terraform until set to false."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "If true, no final snapshot is taken when the instance is destroyed. True is acceptable for dev only."
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to RDS resources."
  type        = map(string)
  default     = {}
}
