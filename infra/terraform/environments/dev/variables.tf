###############################################################################
# Identity / region
###############################################################################

variable "project_name" {
  description = "Project name. Used in resource name prefixes and tags."
  type        = string
  default     = "tasktreat"
}

variable "environment" {
  description = "Environment name (e.g. dev, qa, uat, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources in this environment."
  type        = string
  default     = "us-west-2"
}

variable "owner" {
  description = "Owner tag applied to all resources."
  type        = string
  default     = "leo-zhang"
}

variable "course" {
  description = "Course tag for assignment context."
  type        = string
  default     = "CS-486-CS686"
}

###############################################################################
# Networking
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the public/private subnets. Must align by index with the subnet CIDR lists."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway across AZs (cheaper) instead of one per AZ."
  type        = bool
  default     = true
}

###############################################################################
# EKS
###############################################################################

variable "eks_cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "tasktreat-dev-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes minor version."
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 4
}

variable "eks_node_disk_size_gb" {
  description = "Root disk size for each worker node."
  type        = number
  default     = 40
}

variable "eks_ami_release_version" {
  description = "Specific EKS-optimized AMI release for the node group. Bump this and re-apply to perform a Day 2 OS/security patch via node rotation. Empty string lets EKS pick the latest."
  type        = string
  default     = ""
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Tighten to your IP for tighter dev security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

###############################################################################
# RDS
###############################################################################

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "tasktreat"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
  default     = "tasktreat"
}

variable "db_password" {
  description = "Master DB password. Provide via TF_VAR_db_password or an untracked tfvars file."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class for dev."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version. Must be a version AWS still offers in this region; AWS retires old patches periodically."
  type        = string
  default     = "16.13"
}

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_backup_retention_period" {
  description = "Days to retain automated backups."
  type        = number
  default     = 1
}

variable "db_multi_az" {
  description = "Whether RDS is multi-AZ. Off by default in dev."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy. True in dev only."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "If true, RDS cannot be destroyed via Terraform until set to false."
  type        = bool
  default     = false
}

###############################################################################
# Public DNS / TLS (Step 5)
###############################################################################

variable "domain_name" {
  description = "Apex domain registered at Name.com that this environment serves traffic under (e.g. tasktreat.dev). A Route 53 public hosted zone is created for it."
  type        = string
}

variable "app_subdomain" {
  description = "Hostname label prepended to `domain_name` for the public app (e.g. \"app\" -> app.tasktreat.dev). Set to empty string to serve from the apex."
  type        = string
  default     = "app"
}

###############################################################################
# Step 6: GitHub Actions OIDC (CI/CD)
###############################################################################

variable "github_repository" {
  description = "GitHub repo allowed to deploy via OIDC, as owner/repo. Empty string skips IAM role + EKS access entry creation."
  type        = string
  default     = ""
}

variable "github_oidc_provider_arn" {
  description = "Existing IAM OIDC provider ARN for token.actions.githubusercontent.com. Leave empty so Terraform creates one (import if the provider already exists in this AWS account)."
  type        = string
  default     = ""
}

variable "github_actions_k8s_namespaces" {
  description = "Namespaces the GitHub Actions IAM role may administer in EKS (via access policy association)."
  type        = list(string)
  default = [
    "tasktreat-dev",
    "tasktreat-qa",
    "tasktreat-uat",
    "tasktreat-prod",
    # Step 11–14: lets the deploy workflow apply PrometheusRule manifests
    # and the Grafana Ingress in the monitoring namespace. The initial
    # `helm install` of kube-prometheus-stack / loki / promtail still
    # requires cluster-admin (CRDs are cluster-scoped) and is run from a
    # local admin shell via scripts/install-monitoring.sh.
    "monitoring",
  ]
}

###############################################################################
# Step 11–13: Observability (Grafana public hostname)
###############################################################################

variable "grafana_subdomain" {
  description = "Hostname label prepended to `domain_name` for Grafana (default \"grafana\" -> grafana.tasktreat.dev). Must match the OAuth callback URL configured in the GitHub OAuth App."
  type        = string
  default     = "grafana"
}

variable "grafana_alb_provisioned" {
  description = "Flip to true on the SECOND `terraform apply` — after the Grafana Ingress is applied and the AWS Load Balancer Controller has provisioned its ALB. Gates the Route 53 alias + data source lookup that depends on the ALB existing. Leave false on first apply or `terraform apply` fails with `no matching LB found`."
  type        = bool
  default     = false
}
