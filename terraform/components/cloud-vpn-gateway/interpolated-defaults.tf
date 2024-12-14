locals {
  name                = "${var.cloud_vpn_gateway.name}-${var.env}"
  resource_group_name = var.cloud_vpn_gateway.existing_resource_group_name != null ? var.cloud_vpn_gateway.existing_resource_group_name : azurerm_resource_group.this[0].name
  tags = merge(
    var.cloud_vpn_gateway.tags,
    {
      "application" = "vpn-gateway",
      "environment" = var.env,
    }
  )
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "common"
}

data "azurerm_key_vault_secret" "public_ip" {
  name         = "Home-Public-IP"
  key_vault_id = data.azurerm_key_vault.vault.id
}
