locals {
  tags = merge(
    var.tags,
    {
      "application" = "gameserver",
      "environment" = var.env,
    }
  )
  resource_group_name     = var.gameserver_existing_resource_group_name == null ? azurerm_resource_group.new[0].name : data.azurerm_resource_group.existing[0].name
  resource_group_location = var.gameserver_existing_resource_group_name == null ? azurerm_resource_group.new[0].location : data.azurerm_resource_group.existing[0].location
}
