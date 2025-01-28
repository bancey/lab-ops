resource "azurerm_resource_group" "game_server" {
  name     = "games-${var.env}-rg"
  location = var.location

  tags = local.tags
}
