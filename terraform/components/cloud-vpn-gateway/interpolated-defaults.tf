locals {
  name                = "${var.cloud_vpn_gateway.name}-${var.env}"
  resource_group_name = var.cloud_vpn_gateway.existing_resource_group_name != null ? var.cloud_vpn_gateway.existing_resource_group_name : azurerm_resource_group.this[0].name
  tags = merge(
    var.cloud_vpn_gateway.tags,
    {
      "application" = "vpn-gateway",
      "environment" = var.env,
    }
  )
}
