resource "cloudflare_dns_record" "records" {
  for_each = var.game_servers
  zone_id  = data.azurerm_key_vault_secret.cloudflare_main_zone_id.value
  name     = "${each.key}-${var.env}"
  content  = azurerm_public_ip.this[each.key].ip_address
  type     = "A"
  proxied  = false
  ttl      = 100
}
