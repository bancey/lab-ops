locals {
  openziti_yaml_path = var.openziti_yaml_path != null ? var.openziti_yaml_path : "${path.cwd}/../../environments/${var.env}/openziti.yaml"
  openziti           = yamldecode(file(local.openziti_yaml_path))

  edge_router_policies         = { for p in lookup(local.openziti, "edge_router_policies", []) : p.name => p }
  service_edge_router_policies = { for p in lookup(local.openziti, "service_edge_router_policies", []) : p.name => p }
  service_policies             = { for p in lookup(local.openziti, "service_policies", []) : p.name => p }
  services                     = { for s in lookup(local.openziti, "services", []) : s.name => s }

  # Entra groups named by any policy. Their object IDs become role attributes on auto-enrolled
  # identities (enroll_attr_claims_selector: /groups), so a policy selects them as #<object-id>.
  entra_group_names = toset(flatten([
    for p in values(local.service_policies) : lookup(p, "entra_groups", [])
  ]))
  entra_group_roles = { for name, g in data.azuread_group.this : name => "#${g.object_id}" }
}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "btcs-common-prod"
}

data "azurerm_key_vault_secret" "admin_username" {
  name         = "OpenZiti-Admin-Username"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azurerm_key_vault_secret" "admin_password" {
  name         = "OpenZiti-Admin-Password"
  key_vault_id = data.azurerm_key_vault.vault.id
}

# PEM of the controller's root CA (/var/lib/ziti-controller/pki/<root>/certs/<root>.cert).
# Created by hand once, see docs/openziti.md.
data "azurerm_key_vault_secret" "controller_ca" {
  name         = "OpenZiti-Controller-CA"
  key_vault_id = data.azurerm_key_vault.vault.id
}

data "azuread_group" "this" {
  for_each         = local.entra_group_names
  display_name     = each.value
  security_enabled = true
}
