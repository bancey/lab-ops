resource "azurerm_resource_group" "this" {
  count    = var.cloud_vpn_gateway != null && var.cloud_vpn_gateway != {} && var.cloud_vpn_gateway.existing_resource_group_name == null ? 1 : 0
  name     = "${local.name}-rg"
  location = var.location
}
