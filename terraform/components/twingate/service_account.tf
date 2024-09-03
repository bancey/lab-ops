resource "twingate_service_account" "this" {
  for_each = var.twingate_service_accounts
  name     = each.key
}

resource "time_rotating" "service_account_key_rotation" {
  rotation_days = 7
}

resource "time_static" "service_account_key_rotation" {
  rfc3339 = time_rotating.service_account_key_rotation.rfc3339
}

resource "terraform_data" "sa_replace" {
  for_each = var.twingate_service_accounts
  input    = each.value.trigger_credential_replace
}

resource "twingate_service_account_key" "this" {
  for_each           = var.twingate_service_accounts
  name               = "${each.key} Key (auto rotates)"
  service_account_id = twingate_service_account.this[each.key].id
  lifecycle {
    replace_triggered_by = [
      time_static.service_account_key_rotation,
      terraform_data.sa_replace[each.key]
    ]
  }
}

resource "azurerm_key_vault_secret" "service_account_key" {
  for_each        = var.twingate_service_accounts
  name            = "Twingate-${each.key}-SA-Key"
  value           = twingate_service_account_key.this[each.key].token
  key_vault_id    = data.azurerm_key_vault.vault.id
  expiration_date = time_static.service_account_key_rotation.rfc3339
}
