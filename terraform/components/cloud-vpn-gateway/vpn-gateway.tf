resource "azurerm_virtual_network_gateway" "this" {
  count               = var.cloud_vpn_gateway.active ? 1 : 0
  name                = "${local.name}-gateway"
  location            = var.location
  resource_group_name = local.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.this[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.networking[0].subnet_ids["vpn-gateway"]
  }
}
