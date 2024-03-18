resource "azurerm_resource_group" "gameserver" {
  name     = "games-${var.env}-rg"
  location = var.location

  tags = local.tags
}
