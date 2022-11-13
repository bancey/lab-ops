module "pterodactyl_node" {
  source = "github.com/bancey/terraform-module-pterodactyl-node.git?ref=develop"

  depends_on = [
    module.dns_record
  ]

  count                        = var.gameserver_count
  name                         = "${var.gameserver_name}${count.index + 1}"
  env                          = var.env
  location                     = var.location
  vm_size                      = "Standard_D4as_v5"
  vm_image_publisher           = "canonical"
  vm_image_offer               = "0001-com-ubuntu-server-focal"
  vm_image_sku                 = "20_04-lts-gen2"
  vm_image_version             = "latest"
  vm_domain_name               = "${var.gameserver_name}${count.index + 1}-${var.env}.bancey.xyz"
  existing_public_ip_id        = azurerm_public_ip.this[count.index].id
  existing_resource_group_name = azurerm_resource_group.gameserver.name
  publicly_accessible          = true

  nsg_rules = {
    # Required to allow certbot to generate SSL certificates
    Allow80 : {
      priority                   = 1000
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    Allow22 : {
      priority                   = 1010
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.admin_access_ip
      destination_address_prefix = "*"
    }
    Allow443 : {
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = var.pterodactyl_panel_ip
      destination_address_prefix = "*"
    }
    Allow8080 : {
      priority                   = 1030
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = var.pterodactyl_panel_ip
      destination_address_prefix = "*"
    }
    Allow2022 : {
      priority                   = 1040
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2022"
      source_address_prefix      = var.pterodactyl_panel_ip
      destination_address_prefix = "*"
    }
    AllowGameServerPorts : {
      priority                   = 1050
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = var.gameserver_ports
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  kv_policies = [
    {
      tenant_id               = data.azurerm_client_config.current.tenant_id
      object_id               = "9edd55d1-288c-482b-84a3-508efac9e683"
      application_id          = null
      certificate_permissions = []
      key_permissions         = []
      storage_permissions     = []
      secret_permissions = [
        "Get",
        "List",
        "Set",
        "Delete",
        "Purge",
      ]
    }
  ]
}
