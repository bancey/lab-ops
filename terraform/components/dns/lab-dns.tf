resource "cloudflare_record" "records" {
  for_each = var.cloudflare_records

  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = each.key
  value   = each.value.value == "PublicIP" ? data.azurerm_key_vault_secret.public_ip.value : each.value.value == "@" ? data.azurerm_key_vault_secret.cloudflare_lab_zone_name.value : each.value.value
  type    = each.value.type
  proxied = each.value.proxied
  ttl     = each.value.ttl
}
