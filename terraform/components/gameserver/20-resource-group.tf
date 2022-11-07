resource "azurerm_resource_group" "new" {
  count = var.existing_resource_group_name == null ? 1 : 0

  name     = "${var.name}-${var.env}-rg"
  location = var.location

  tags = local.tags
}

data "azurerm_resource_group" "existing" {
  count = var.existing_resource_group_name == null ? 0 : 1
  name  = var.existing_resource_group_name
}
