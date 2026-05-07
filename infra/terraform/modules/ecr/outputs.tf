output "repository_urls" {
  description = "Map of bare repository name -> repository URL (for docker push/pull)."
  value = {
    for k, repo in aws_ecr_repository.this : k => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of bare repository name -> repository ARN."
  value = {
    for k, repo in aws_ecr_repository.this : k => repo.arn
  }
}

output "frontend_repository_url" {
  description = "Repository URL for the frontend image. Empty if no `frontend` repository was requested."
  value       = try(aws_ecr_repository.this["frontend"].repository_url, "")
}

output "task_service_repository_url" {
  description = "Repository URL for task-service. Empty if not requested."
  value       = try(aws_ecr_repository.this["task-service"].repository_url, "")
}

output "wishlist_service_repository_url" {
  description = "Repository URL for wishlist-service. Empty if not requested."
  value       = try(aws_ecr_repository.this["wishlist-service"].repository_url, "")
}

output "reward_service_repository_url" {
  description = "Repository URL for reward-service. Empty if not requested."
  value       = try(aws_ecr_repository.this["reward-service"].repository_url, "")
}
