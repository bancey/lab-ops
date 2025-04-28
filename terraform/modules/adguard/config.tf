resource "adguard_config" "config" {
  filtering = {
    enabled         = var.adguard_config.filtering.enabled
    update_interval = var.adguard_config.filtering.update_interval
  }

  querylog = {
    enabled             = var.adguard_config.query_log.enabled
    interval            = var.adguard_config.query_log.interval
    anonymize_client_ip = var.adguard_config.query_log.anonymize_client_ip
  }

  stats = {
    enabled  = var.adguard_config.stats.enabled
    interval = var.adguard_config.stats.interval
  }

  dns = {
    upstream_dns  = var.adguard_config.dns.upstream_dns
    upstream_mode = var.adguard_config.dns.upstream_mode
    fallback_dns  = var.adguard_config.dns.fallback_dns
    bootstrap_dns = var.adguard_config.dns.bootstrap_dns
    rate_limit    = var.adguard_config.dns.rate_limit
  }

  dhcp = {
    enabled   = false
    interface = "eth0"
  }
}
