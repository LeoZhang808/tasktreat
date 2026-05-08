variable "cluster_name" {
  description = "EKS cluster name. Used to namespace the IAM role/policy."
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider associated with the EKS cluster (output `oidc_provider_arn` of the eks module)."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster (https://oidc.eks.<region>.amazonaws.com/id/...)."
  type        = string
}

variable "service_account_namespace" {
  description = "Kubernetes namespace where the controller service account lives. Must match what Helm installs."
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Kubernetes service account name the controller uses. Must match what Helm installs."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
