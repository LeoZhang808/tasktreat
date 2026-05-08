variable "domain_name" {
  description = "Primary FQDN the certificate is issued for (e.g. app.tasktreat.dev)."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional FQDNs the certificate should also cover. Useful for adding the apex or a wildcard."
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID where DNS validation CNAME records will be created. Must be authoritative for `domain_name`."
  type        = string
}

variable "validation_timeout" {
  description = "How long Terraform will wait for ACM to mark the certificate ISSUED. ACM normally validates within minutes; bump this if Name.com nameservers were just delegated and DNS is still propagating."
  type        = string
  default     = "30m"
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  default     = {}
}
