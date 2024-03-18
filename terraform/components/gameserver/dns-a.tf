resource "cloudflare_record" "records" {
  for_each = var.gameservers
  zone_id  = data.azurerm_key_vault_secret.cloudflare_main_zone_id.value
  name     = "${each.key}-${var.env}"
  value    = azurerm_public_ip.this[each.key].ip_address
  type     = "A"
  proxied  = false
  ttl      = 100
}
