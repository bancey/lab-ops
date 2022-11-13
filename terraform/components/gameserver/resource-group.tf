resource "azurerm_resource_group" "gameserver" {
  name     = "${var.gameserver_name}-${var.env}-rg"
  location = var.location

  tags = local.tags
}
