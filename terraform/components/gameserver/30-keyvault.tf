data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "${var.gameserver_name}-${var.env}-kv"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}
