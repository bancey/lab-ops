# Client secret lifecycle, mirroring the rotation pattern used for Twingate service account keys
# in terraform/components/twingate/service_account.tf: a time_rotating resource defines the
# interval, a time_static pins the current period, and replace_triggered_by re-issues the
# credential when the period rolls over.
#
# NOTE: unlike the Twingate keys, which Ansible re-reads from Key Vault on every pipeline run,
# Kubernetes consumers read these secrets from SOPS files committed to git. A rotation therefore
# does NOT reach the cluster until scripts/sync-entra-secret.sh is re-run and the result committed.
# rotation_days defaults to 730 so this is a deliberate, scheduled operation rather than a surprise.
resource "time_rotating" "secret_rotation" {
  for_each      = local.app_secrets
  rotation_days = local.secret_rotation_days[each.key]
}

resource "time_static" "secret_rotation" {
  for_each = local.app_secrets
  rfc3339  = time_rotating.secret_rotation[each.key].rfc3339
}

resource "azuread_application_password" "this" {
  for_each       = local.app_secrets
  application_id = azuread_application.this[each.key].id
  display_name   = "${each.key} (terraform managed)"
  end_date       = timeadd(time_static.secret_rotation[each.key].rfc3339, "${(local.secret_rotation_days[each.key] + 30) * 24}h")

  lifecycle {
    replace_triggered_by = [
      time_static.secret_rotation[each.key]
    ]
  }
}

resource "azurerm_key_vault_secret" "client_secret" {
  for_each        = local.app_secrets
  name            = "Entra-${local.key_vault_prefixes[each.key]}-Client-Secret"
  value           = azuread_application_password.this[each.key].value
  key_vault_id    = data.azurerm_key_vault.vault.id
  content_type    = "Entra ID client secret"
  expiration_date = timeadd(time_static.secret_rotation[each.key].rfc3339, "${(local.secret_rotation_days[each.key] + 30) * 24}h")
}

# The client ID is not a secret, but storing it next to the secret means
# scripts/sync-entra-secret.sh can fetch both halves of a credential from one place.
resource "azurerm_key_vault_secret" "client_id" {
  for_each     = local.applications
  name         = "Entra-${local.key_vault_prefixes[each.key]}-Client-ID"
  value        = azuread_application.this[each.key].client_id
  key_vault_id = data.azurerm_key_vault.vault.id
  content_type = "Entra ID application (client) ID"
}
