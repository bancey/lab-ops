output "nsg_rules" {
  value = {
    Allow22 : {
      priority                   = 1010
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.source_address_prefix
      destination_address_prefix = "*"
    }
    Allow443 : {
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = var.source_address_prefix
      destination_address_prefix = "*"
    }
    Allow8080 : {
      priority                   = 1030
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = var.source_address_prefix
      destination_address_prefix = "*"
    }
    Allow2022 : {
      priority                   = 1040
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2022"
      source_address_prefix      = var.source_address_prefix
      destination_address_prefix = "*"
    }
    AllowGameServerPorts : {
      priority                   = 1050
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = var.source_address_prefix
      source_address_prefix      = var.publicly_accessible ? "*" : var.source_address_prefix
      destination_address_prefix = "*"
    }
    DenyAll : {
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
