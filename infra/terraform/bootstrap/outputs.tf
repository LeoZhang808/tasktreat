output "state_bucket" {
  description = "S3 bucket holding remote Terraform state."
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.tf_state.arn
}

output "lock_table" {
  description = "DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.tf_locks.name
}

output "aws_region" {
  description = "Region the bootstrap resources live in."
  value       = var.aws_region
}
