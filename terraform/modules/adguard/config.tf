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
    interface = "eth0"
    enabled   = false
    ipv4_settings = {
      gateway_ip  = "172.18.0.1"
      range_end   = "172.18.0.200"
      range_start = "172.18.0.100"
      subnet_mask = "255.255.255.0"
    }
  }
}
