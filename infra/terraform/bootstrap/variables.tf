variable "project_name" {
  description = "Project name used to prefix bootstrap resources."
  type        = string
  default     = "tasktreat"
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-west-2"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state. If empty, a name is generated from project_name and the account id."
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "tasktreat-tf-locks"
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default = {
    Project     = "tasktreat"
    Environment = "shared"
    ManagedBy   = "terraform"
    Component   = "bootstrap"
    Course      = "CS-486-CS686"
  }
}
