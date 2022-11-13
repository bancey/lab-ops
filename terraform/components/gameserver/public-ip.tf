resource "azurerm_public_ip" "this" {
  count               = var.gameserver_count
  name                = "${var.gameserver_name}${count.index + 1}-${var.env}-pip"
  location            = azurerm_resource_group.gameserver.location
  resource_group_name = azurerm_resource_group.gameserver.name
  allocation_method   = "Static"

  tags = local.tags
}
