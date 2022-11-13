data "azurerm_client_config" "current" {}

locals {
  tags = {
    "application" = "pterodactyl",
    "environment" = var.env,
  }
}
