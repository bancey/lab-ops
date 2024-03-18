module "pterodactyl_node" {
  source = "github.com/bancey/terraform-module-pterodactyl-node.git?ref=feat%2Freference-existing-networking"

  depends_on = [
    cloudflare_record.records
  ]

  for_each = { for k, v in var.gameservers : k => v if v.type == "pterodactyl" }

  name               = "${each.key}-${var.env}"
  env                = var.env
  location           = var.location
  vm_size            = each.value.size
  vm_image_publisher = "canonical"
  vm_image_offer     = "0001-com-ubuntu-server-focal"
  vm_image_sku       = "20_04-lts-gen2"
  vm_image_version   = "latest"
  vm_domain_name     = each.value.domain_name == null ? "${each.key}-${var.env}.bancey.xyz" : each.value.domain_name
  existing_public_ip = {
    name                = azurerm_public_ip.this[each.key].name
    resource_group_name = azurerm_resource_group.gameserver.name
  }
  existing_resource_group_name       = azurerm_resource_group.gameserver.name
  existing_subnet_id                 = azurerm_subnet.this.id
  existing_network_security_group_id = azurerm_network_security_group.this.id
  publicly_accessible                = true

  vm_shutdown_schedule = {
    enabled  = true
    time     = "2300"
    timezone = "GMT Standard Time"
  }

  enable_aad_login = true

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
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow443 : {
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow8080 : {
      priority                   = 1030
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    Allow2022 : {
      priority                   = 1040
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "2022"
      source_address_prefix      = data.azurerm_key_vault_secret.public_ip.value
      destination_address_prefix = "*"
    }
    AllowGameServerPorts : {
      priority                   = 1050
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = data.azurerm_key_vault_secret.game_server_ports.value
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
