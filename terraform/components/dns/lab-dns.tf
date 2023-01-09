resource "cloudflare_record" "root" {
  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = "@"
  value   = data.azurerm_key_vault_secret.public_ip.value
  type    = "A"
  proxied = true
  ttl     = 300
}

resource "cloudflare_record" "cnames" {
  count   = length(var.cloudflare_cname_record_names)
  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = var.cloudflare_cname_record_names[count.index]
  value   = "@"
  type    = "CNAME"
  proxied = true
  ttl     = 300
}
