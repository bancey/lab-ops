resource "cloudflare_dns_record" "records" {
  provider = cloudflare.lab
  for_each = { for key, value in var.cloudflare_records : key => value if value.zone == "lab" }

  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = each.key
  content = each.value.value == "PublicIP" ? data.azurerm_key_vault_secret.public_ip.value : each.value.value == "@" ? data.azurerm_key_vault_secret.cloudflare_lab_zone_name.value : each.value.value
  type    = each.value.type
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "main_records" {
  provider = cloudflare.main
  for_each = { for key, value in var.cloudflare_records : key => value if value.zone == "main" }

  zone_id = data.azurerm_key_vault_secret.cloudflare_main_zone_id.value
  name    = each.key
  content = each.value.value == "PublicIP" ? data.azurerm_key_vault_secret.public_ip.value : each.value.value == "@" ? data.azurerm_key_vault_secret.cloudflare_main_zone_name.value : each.value.value
  type    = each.value.type
  proxied = each.value.proxied
  ttl     = each.value.ttl
}
