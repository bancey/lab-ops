resource "azurerm_public_ip" "this" {
  count               = var.gameserver_count
  name                = "${var.gameserver_name}-${var.env}-pip${count.index + 1}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"

  tags = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.gameserver_name}-${var.env}-vnet"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  address_space       = var.gameserver_vnet_address_space

  tags = local.tags
}

resource "azurerm_subnet" "this" {
  name                 = "${var.gameserver_name}-${var.env}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.gameserver_vnet_address_space
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.gameserver_name}-${var.env}-nsg"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  tags                = local.tags
}

resource "azurerm_network_security_rule" "Allow_SSH" {
  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = local.resource_group_name
  name                        = "AllowSSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  source_address_prefix       = var.admin_access_ip
}

resource "azurerm_network_security_rule" "Allow_443" {
  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = local.resource_group_name
  name                        = "Allow443"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  source_address_prefix       = var.admin_access_ip
}

resource "azurerm_network_security_rule" "Allow_8080" {
  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = local.resource_group_name
  name                        = "Allow8080"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "8080"
  destination_address_prefix  = "*"
  source_address_prefix       = var.admin_access_ip
}

resource "azurerm_network_security_rule" "Allow_2022" {
  network_security_group_name = azurerm_network_security_group.this.name
  resource_group_name         = local.resource_group_name
  name                        = "Allow2022"
  priority                    = 1030
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "2022"
  destination_address_prefix  = "*"
  source_address_prefix       = var.admin_access_ip
}

resource "azurerm_network_interface" "this" {
  count               = var.gameserver_count
  name                = "${var.gameserver_name}-${var.env}-nic${count.index + 1}"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "${var.gameserver_name}-${var.env}-ipconfig"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.this[count.index].id
  }

  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "this" {
  count                     = var.gameserver_count
  network_interface_id      = azurerm_network_interface.this[count.index].id
  network_security_group_id = azurerm_network_security_group.this.id
}
