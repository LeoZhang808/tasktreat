output "zone_id" {
  description = "Route 53 hosted zone ID. Pass this into the ACM module so it can create DNS validation records."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Apex domain name managed by this hosted zone."
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "Authoritative nameservers for the zone. After the first apply, paste these four into Name.com to delegate DNS to Route 53."
  value       = aws_route53_zone.this.name_servers
}
