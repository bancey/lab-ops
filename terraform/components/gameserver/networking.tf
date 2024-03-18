resource "azurerm_public_ip" "this" {
  for_each            = var.gameservers
  name                = "${each.key}-${var.env}-pip"
  location            = azurerm_resource_group.gameserver.location
  resource_group_name = azurerm_resource_group.gameserver.name
  allocation_method   = "Static"

  tags = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "games-${var.env}-vnet"
  location            = azurerm_resource_group.gameserver.location
  resource_group_name = azurerm_resource_group.gameserver.name
  address_space       = var.gameservers_vnet_address_space

  tags = local.tags
}

resource "azurerm_subnet" "this" {
  name                 = "games-${var.env}-subnet"
  resource_group_name  = azurerm_resource_group.gameserver.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.gameservers_vnet_address_space
}

resource "azurerm_network_security_group" "this" {
  name                = "games-${var.env}-nsg"
  resource_group_name = azurerm_resource_group.gameserver.name
  location            = azurerm_resource_group.gameserver.location
  tags                = local.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = merge(local.nsg_rules, var.nsg_rules)

  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = azurerm_resource_group.gameserver.name

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

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
