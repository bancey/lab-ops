resource "azurerm_public_ip" "this" {
  for_each            = var.game_servers
  name                = "${each.key}-${var.env}-pip"
  location            = azurerm_resource_group.game_server.location
  resource_group_name = azurerm_resource_group.game_server.name
  allocation_method   = "Static"

  tags = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "games-${var.env}-vnet"
  location            = azurerm_resource_group.game_server.location
  resource_group_name = azurerm_resource_group.game_server.name
  address_space       = var.game_server_vnet_address_space

  tags = local.tags
}

data "azurerm_virtual_network" "remote" {
  for_each            = var.game_server_vnet_peerings
  name                = each.value.vnet_name
  resource_group_name = each.value.vnet_resource_group_name
}

resource "azurerm_virtual_network_peering" "local_to_remote" {
  for_each                  = var.game_server_vnet_peerings
  name                      = "games-${var.env}-to-${each.key}"
  resource_group_name       = azurerm_resource_group.game_server.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = data.azurerm_virtual_network.remote[each.key].id
}

resource "azurerm_virtual_network_peering" "remote_to_local" {
  for_each                  = var.game_server_vnet_peerings
  name                      = "${each.key}-to-games-${var.env}"
  resource_group_name       = data.azurerm_virtual_network.remote[each.key].resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.remote[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.this.id
}

resource "azurerm_subnet" "this" {
  for_each             = { private : cidrsubnet(var.game_server_vnet_address_space, 1, 0), public : cidrsubnet(var.game_server_vnet_address_space, 1, 1) }
  name                 = "games-${var.env}-${each.key}-subnet"
  resource_group_name  = azurerm_resource_group.game_server.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]
}

resource "azurerm_network_security_group" "this" {
  for_each            = toset("private", "public")
  name                = "games-${var.env}-${each.key}-nsg"
  resource_group_name = azurerm_resource_group.game_server.name
  location            = azurerm_resource_group.game_server.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = toset("private", "public")
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_network_security_rule" "this" {
  for_each = { private : module.private_nsg_rules.nsg_rules, public : module.public_nsg_rules.nsg_rules }

  network_security_group_name = azurerm_network_security_group.this[each.key].name
  resource_group_name         = azurerm_resource_group.game_server.name

  name                       = each.key
  priority                   = each.value.priority
  direction                  = each.value.direction
  access                     = each.value.access
  protocol                   = each.value.protocol
  source_port_range          = each.value.source_port_range
  destination_port_range     = each.value.destination_port_range
  source_address_prefix      = each.value.source_address_prefix
  destination_address_prefix = each.value.destination_address_prefix
}
