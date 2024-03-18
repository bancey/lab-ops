resource "twingate_service_account" "this" {
  for_each = toset(var.twingate_service_accounts)
  name     = each.value
}

resource "time_rotating" "service_account_key_rotation" {
  rotation_days = 7
}

resource "time_static" "service_account_key_rotation" {
  rfc3339 = time_rotating.service_account_key_rotation.rfc3339
}

resource "twingate_service_account_key" "this" {
  for_each           = toset(var.twingate_service_accounts)
  name               = "${each.value} Key (auto rotates)"
  service_account_id = twingate_service_account.this[each.key].id
  lifecycle {
    replace_triggered_by = [time_static.service_account_key_rotation]
  }
}

resource "azurerm_key_vault_secret" "service_account_key" {
  for_each     = toset(var.twingate_service_accounts)
  name         = "Twingate-${each.value}-SA-Key"
  value        = twingate_service_account_key.this[each.key].token
  key_vault_id = data.azurerm_key_vault.vault.id
}