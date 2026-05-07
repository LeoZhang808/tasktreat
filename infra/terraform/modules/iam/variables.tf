variable "name_prefix" {
  description = "Prefix used to name IAM roles, e.g. tasktreat-dev."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
