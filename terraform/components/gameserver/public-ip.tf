resource "azurerm_public_ip" "this" {
  for_each            = var.gameservers
  name                = "${each.key}-${var.env}-pip"
  location            = azurerm_resource_group.gameserver.location
  resource_group_name = azurerm_resource_group.gameserver.name
  allocation_method   = "Static"

  tags = local.tags
}
