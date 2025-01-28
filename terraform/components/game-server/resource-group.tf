resource "azurerm_resource_group" "game_server" {
  name     = "games-${var.env}-rg"
  location = var.location

  tags = local.tags
}

moved {
  from = azurerm_resource_group.gameserver
  to   = azurerm_resource_group.game_server
}
