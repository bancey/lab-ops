resource "cloudflare_record" "wings_cname" {
  for_each = {
    for name, vm in var.virtual_machines : name => vm
    if vm.cname_required
  }

  zone_id = data.azurerm_key_vault_secret.cloudflare_lab_zone_id.value
  name    = each.key
  value   = data.azurerm_key_vault_secret.cloudflare_lab_zone_name.value
  type    = "CNAME"
  proxied = "true"
  ttl     = 1
}
