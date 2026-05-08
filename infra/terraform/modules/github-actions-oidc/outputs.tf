output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions (set as AWS_DEPLOY_ROLE_ARN in CI)."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider used by the role trust policy."
  value       = local.github_oidc_arn
}
