variable "domain_name" {
  description = "Apex domain to create a public hosted zone for, e.g. tasktreat.dev. Must match the domain registered at Name.com."
  type        = string
}

variable "force_destroy" {
  description = "If true, allow `terraform destroy` to remove the zone even if it still contains records. Convenient in dev, dangerous in prod."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  default     = {}
}
