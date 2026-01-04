module "game_server_node" {
  source = "github.com/bancey/terraform-azurerm-game-server.git?ref=copilot/update-provisioning-for-pelican"

  depends_on = [
    cloudflare_dns_record.records
  ]

  for_each = var.game_servers

  name               = each.key
  env                = var.env
  location           = var.location
  vm_size            = each.value.size
  vm_image_publisher = "canonical"
  vm_image_offer     = "ubuntu-24_04-lts"
  vm_image_sku       = "server"
  vm_image_version   = "latest"
  provisioning_type  = each.value.type
  certificate_config = {
    domain_name = each.value.domain_name == null ? "${each.key}-${var.env}.bancey.xyz" : each.value.domain_name
    email       = "abance@bancey.xyz"
  }
  existing_public_ip = {
    name                = azurerm_public_ip.this[each.key].name
    resource_group_name = azurerm_resource_group.game_server.name
  }
  existing_resource_group_name = azurerm_resource_group.game_server.name
  existing_subnet_id           = each.value.publicly_accessible ? azurerm_subnet.this["public"].id : azurerm_subnet.this["private"].id
  existing_nsg_id              = each.value.publicly_accessible ? azurerm_network_security_group.this["public"].id : azurerm_network_security_group.this["private"].id
  publicly_accessible          = true

  vm_shutdown_schedule = {
    enabled  = true
    time     = "2300"
    timezone = "GMT Standard Time"
  }

  enable_aad_login = true

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

  tags = {
    "DiscordControl" : "true"
  }
}

resource "azurerm_role_assignment" "reader" {
  for_each             = var.game_servers
  scope                = "/subscriptions/ca9663cd-26bb-4c47-b084-e527a512d372/resourceGroups/common/providers/Microsoft.KeyVault/vaults/bancey-vault"
  role_definition_name = "Reader"
  principal_id         = module.game_server_node[each.key].vm_identity[0].principal_id
}

resource "azuread_group_member" "kv_reader" {
  for_each         = var.game_servers
  group_object_id  = "9edd55d1-288c-482b-84a3-508efac9e683"
  member_object_id = module.game_server_node[each.key].vm_identity[0].principal_id
}

resource "terraform_data" "trigger_replace" {
  input = data.azurerm_key_vault_secret.twingate_pelican_sa_key.expiration_date
}

resource "azurerm_virtual_machine_extension" "setup_twingate" {
  depends_on                 = [azuread_group_member.kv_reader, azurerm_role_assignment.reader]
  for_each                   = var.game_servers
  name                       = "SetupTwingate"
  virtual_machine_id         = module.game_server_node[each.key].vm_id
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  protected_settings = <<PROTECTED_SETTINGS
  {
    "script": "${base64encode(templatefile("${path.module}/provision/setup-twingate.sh", { TWINGATE_SERVICE_KEY = data.azurerm_key_vault_secret.twingate_pelican_sa_key.value }))}"
  }
  PROTECTED_SETTINGS

  lifecycle {
    replace_triggered_by = [terraform_data.trigger_replace]
  }
}
