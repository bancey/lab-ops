module "dns_record" {
  source = "../../modules/dns-record"
  count  = var.gameserver_count

  subdomain   = "${var.gameserver_name}${count.index + 1}-${var.env}"
  record_type = "A"
  ttl         = "0"
  ip_address  = azurerm_public_ip.this.ip_address
}
