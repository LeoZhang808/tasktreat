output "role_arn" {
  description = "ARN of the IAM role the controller assumes via IRSA. Annotate the in-cluster service account with `eks.amazonaws.com/role-arn=<this>` (the Helm chart does this when serviceAccount.annotations is set)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the customer-managed IAM policy attached to the role."
  value       = aws_iam_policy.this.arn
}

output "service_account_namespace" {
  description = "Namespace the service account must live in for the trust policy to match."
  value       = var.service_account_namespace
}

output "service_account_name" {
  description = "Service account name the trust policy is scoped to."
  value       = var.service_account_name
}
