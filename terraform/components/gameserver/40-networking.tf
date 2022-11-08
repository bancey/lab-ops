resource "azurerm_public_ip" "this" {
  name                = "${var.gameserver_name}-${var.env}-pip"
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

resource "azurerm_network_interface" "this" {
  name                = "${var.gameserver_name}-${var.env}-nic"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "${var.gameserver_name}-${var.env}-ipconfig"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.this.id
  }

  tags = local.tags
}
