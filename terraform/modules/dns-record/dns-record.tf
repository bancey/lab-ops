resource "ovh_domain_zone_record" "this" {
  zone      = local.ovh_zone
  subdomain = var.subdomain
  fieldtype = var.record_type
  ttl       = var.ttl
  target    = var.ip_address
}
