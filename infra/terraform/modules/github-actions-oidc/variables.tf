variable "role_name" {
  description = "IAM role name assumed by GitHub Actions (e.g. tasktreat-github-actions-deploy-role)."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = <<-EOT
    Existing IAM OIDC provider ARN for https://token.actions.githubusercontent.com.
    Leave empty to create the provider in this module (fails if one already exists in the account — import it or pass the ARN here).
  EOT
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the role, as OWNER/REPO (no https:// or github.com prefix)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like \"owner/repo\"."
  }
}

variable "eks_cluster_name" {
  description = "EKS cluster name. Used to scope eks:DescribeCluster if desired."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs this role may push and pull."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
