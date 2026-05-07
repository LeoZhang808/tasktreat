variable "name_prefix" {
  description = "Prefix used to name ECR repositories, e.g. tasktreat-dev."
  type        = string
}

variable "repository_names" {
  description = "Bare repository names (without the prefix). Each becomes <name_prefix>-<name>."
  type        = list(string)
  default = [
    "frontend",
    "task-service",
    "wishlist-service",
    "reward-service",
  ]
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. MUTABLE is convenient for dev; later environments should use IMMUTABLE."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "If true, ECR scans images for vulnerabilities on push."
  type        = bool
  default     = true
}

variable "untagged_image_expiry_days" {
  description = "Days after which untagged images are removed by lifecycle policy."
  type        = number
  default     = 14
}

variable "max_tagged_image_count" {
  description = "Maximum number of tagged images to retain per repository."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every repository."
  type        = map(string)
  default     = {}
}
