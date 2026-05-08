output "certificate_arn" {
  description = "ARN of the validated ACM certificate. Wire this into the Ingress' `alb.ingress.kubernetes.io/certificate-arn` annotation."
  # Use the ARN exposed by the validation resource so consumers wait until
  # the cert is actually ISSUED before using it.
  value = aws_acm_certificate_validation.this.certificate_arn
}

output "certificate_domain_name" {
  description = "Primary FQDN the certificate covers."
  value       = aws_acm_certificate.this.domain_name
}

output "certificate_status" {
  description = "Current ACM certificate status. Should be ISSUED after a successful apply."
  value       = aws_acm_certificate.this.status
}

output "certificate_validation_emails" {
  description = "Validation emails (empty for DNS-validated certs; kept for symmetry with other modules)."
  value       = aws_acm_certificate.this.validation_emails
}
