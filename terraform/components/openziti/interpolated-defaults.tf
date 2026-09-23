data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "btcs-common-prod"
}

data "azurerm_key_vault_secret" "wanda_proxmox_url" {
  name         = "Wanda-Proxmox-URL"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_username" {
  name         = "Wanda-Proxmox-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "wanda_proxmox_password" {
  name         = "Wanda-Proxmox-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_username" {
  name         = "Lab-VM-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "lab_vm_password" {
  name         = "Lab-VM-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "openziti_admin_username" {
  name         = "OpenZiti-Admin-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "openziti_admin_password" {
  name         = "OpenZiti-Admin-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}
