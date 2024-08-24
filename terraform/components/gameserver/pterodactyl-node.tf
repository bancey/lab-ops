module "pterodactyl_node" {
  source = "github.com/bancey/terraform-azurerm-pterodactyl-node.git?ref=main"

  depends_on = [
    cloudflare_record.records
  ]

  for_each = { for k, v in var.gameservers : k => v if v.type == "pterodactyl" }

  name               = each.key
  env                = var.env
  location           = var.location
  vm_size            = each.value.size
  vm_image_publisher = "canonical"
  vm_image_offer     = "0001-com-ubuntu-server-jammy"
  vm_image_sku       = "22_04-lts-gen2"
  vm_image_version   = "latest"
  certificate_config = {
    domain_name = each.value.domain_name == null ? "${each.key}-${var.env}.bancey.xyz" : each.value.domain_name
    email       = "abance@bancey.xyz"
  }
  existing_public_ip = {
    name                = azurerm_public_ip.this[each.key].name
    resource_group_name = azurerm_resource_group.gameserver.name
  }
  existing_resource_group_name = azurerm_resource_group.gameserver.name
  existing_subnet_id           = azurerm_subnet.this.id
  existing_nsg_id              = azurerm_network_security_group.this.id
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
  for_each             = { for k, v in var.gameservers : k => v if v.type == "pterodactyl" }
  scope                = "/subscriptions/5a8abf1c-0a69-49c6-bcf1-676843b64217/resourceGroups/common/providers/Microsoft.KeyVault/vaults/bancey-vault"
  role_definition_name = "Reader"
  principal_id         = module.pterodactyl_node[each.key].vm_identity[0].principal_id
}

resource "azuread_group_member" "kv_reader" {
  for_each         = { for k, v in var.gameservers : k => v if v.type == "pterodactyl" }
  group_object_id  = "9edd55d1-288c-482b-84a3-508efac9e683"
  member_object_id = module.pterodactyl_node[each.key].vm_identity[0].principal_id
}

resource "terraform_data" "pterodactyl_sa_key" {
  input = data.azurerm_key_vault_secret.twingate_pterodactyl_sa_key.value
}

resource "azurerm_virtual_machine_extension" "setup_twingate" {
  depends_on                 = [azuread_group_member.kv_reader, azurerm_role_assignment.reader]
  for_each                   = { for k, v in var.gameservers : k => v if v.type == "pterodactyl" }
  name                       = "SetupTwingate"
  virtual_machine_id         = module.pterodactyl_node[each.key].vm_id
  publisher                  = "Microsoft.CPlat.Core"
  type                       = "RunCommandLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = local.tags

  protected_settings = <<PROTECTED_SETTINGS
  {
    "script": "${base64encode(templatefile("${path.module}/provision/setup-twingate.sh", { TWINGATE_SERVICE_KEY = data.azurerm_key_vault_secret.twingate_pterodactyl_sa_key.value }))}"
  }
  PROTECTED_SETTINGS

  lifecycle {
    replace_triggered_by = [terraform_data.pterodactyl_sa_key]
  }
}
