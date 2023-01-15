resource "cloudflare_record" "wings_cname" {
  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = "wings1"
  value   = data.azurerm_key_vault_secret.cloudflare_lab_zone_name.value
  type    = "CNAME"
  proxied = "true"
  ttl     = 1
}
