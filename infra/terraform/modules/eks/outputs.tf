output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert (used by kubeconfig)."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes minor version of the cluster."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group automatically created by EKS for control plane <-> node communication."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.this.node_group_name
}

output "node_group_arn" {
  description = "ARN of the managed node group."
  value       = aws_eks_node_group.this.arn
}
