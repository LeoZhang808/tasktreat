variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version. Bump to perform a control-plane upgrade through Terraform."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC the cluster lives in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets where worker nodes run. The control-plane ENIs will also be placed here."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets attached to the control plane (used for public load balancers later)."
  type        = list(string)
  default     = []
}

variable "cluster_role_arn" {
  description = "IAM role ARN assumed by the EKS control plane (created by the iam module)."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN attached to managed node group EC2 instances (created by the iam module)."
  type        = string
}

variable "node_group_name" {
  description = "Name of the managed node group."
  type        = string
  default     = "workers"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT for the managed node group."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "node_disk_size_gb" {
  description = "Root disk size for each worker node, in GB."
  type        = number
  default     = 40
}

variable "ami_release_version" {
  description = "Specific EKS-optimized AMI release version for the node group. Bump and apply to force a node rotation for OS/security patching. Empty string lets EKS pick the latest for the chosen Kubernetes version."
  type        = string
  default     = ""
}

variable "cluster_endpoint_public_access" {
  description = "Whether the cluster API endpoint is reachable from the public internet."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the cluster API endpoint is reachable from inside the VPC."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Allowed CIDR blocks for public API access. Default is 0.0.0.0/0; restrict to your IP for tighter dev security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to EKS resources."
  type        = map(string)
  default     = {}
}
