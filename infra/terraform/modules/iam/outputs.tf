output "eks_cluster_role_arn" {
  description = "ARN of the IAM role assumed by the EKS control plane."
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role."
  value       = aws_iam_role.eks_cluster.name
}

output "eks_node_role_arn" {
  description = "ARN of the IAM role attached to EKS managed node group EC2 instances."
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  description = "Name of the EKS node group IAM role."
  value       = aws_iam_role.eks_node.name
}
