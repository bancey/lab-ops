resource "azurerm_virtual_network_gateway" "this" {
  count               = var.cloud_vpn_gateway.active ? 1 : 0
  name                = "${local.name}-gateway"
  location            = var.location
  resource_group_name = local.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.this[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.networking[0].subnet_ids["vpn-gateway"]
  }
}

resource "azurerm_local_network_gateway" "lab" {
  count               = var.cloud_vpn_gateway.active ? 1 : 0
  name                = "${local.name}-local-gateway"
  resource_group_name = local.resource_group_name
  location            = var.location
  gateway_address     = data.azurerm_key_vault_secret.public_ip.value
  address_space       = ["10.151.0.0/18"]
}

resource "random_string" "shared_key" {
  count   = var.cloud_vpn_gateway.active ? 1 : 0
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "shared_key" {
  count        = var.cloud_vpn_gateway.active ? 1 : 0
  key_vault_id = data.azurerm_key_vault.vault.id
  name         = "${local.name}-shared-key"
  value        = random_string.shared_key[0].result
}

resource "azurerm_virtual_network_gateway_connection" "lab-s2s" {
  name                = "${local.name}-s2s-connection"
  location            = var.location
  resource_group_name = local.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.lab[0].id

  shared_key          = random_string.shared_key[0].result
  connection_protocol = "IKEv1"

}
