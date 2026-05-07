variable "name_prefix" {
  description = "Prefix used to name VPC resources, e.g. tasktreat-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per AZ."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per AZ."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across. Must align by index with the subnet CIDR lists."
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster these subnets will host. Used to tag subnets so the AWS Load Balancer Controller can discover them later."
  type        = string
}

variable "single_nat_gateway" {
  description = "If true, create a single shared NAT Gateway in the first public subnet (cheaper for dev). If false, create one NAT per AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources in the module."
  type        = map(string)
  default     = {}
}
