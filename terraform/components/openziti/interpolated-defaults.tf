locals {
  openziti_yaml_path = var.openziti_yaml_path != null ? var.openziti_yaml_path : "${path.cwd}/../../environments/${var.env}/openziti.yaml"
  openziti           = yamldecode(file(local.openziti_yaml_path))
  repo_root          = "${path.cwd}/../../.."

  edge_router_policies         = { for p in lookup(local.openziti, "edge_router_policies", []) : p.name => p }
  service_edge_router_policies = { for p in lookup(local.openziti, "service_edge_router_policies", []) : p.name => p }
  service_policies             = { for p in lookup(local.openziti, "service_policies", []) : p.name => p }
  services                     = { for s in lookup(local.openziti, "services", []) : s.name => s }

  entra_group_names = toset(flatten([
    for p in values(local.service_policies) : lookup(p, "entra_groups", [])
  ]))

  entra_group_ids      = { for g in data.azuread_group.lab : g.display_name => g.object_id }
  entra_group_roles    = { for name in local.entra_group_names : name => "#${local.entra_group_ids[name]}" if contains(keys(local.entra_group_ids), name) }
  missing_entra_groups = sort([for name in local.entra_group_names : name if !contains(keys(local.entra_group_ids), name)])

  # Dial identity roles per policy, with unresolved groups skipped. A policy with nothing to select
  # is not created yet, rather than created matching no one (or, worse, everyone).
  service_policy_identity_roles = {
    for name, p in local.service_policies : name => concat(
      lookup(p, "identity_roles", []),
      [for group in lookup(p, "entra_groups", []) : local.entra_group_roles[group] if contains(keys(local.entra_group_roles), group)],
    )
  }
  active_service_policies = { for name, p in local.service_policies : name => p if length(local.service_policy_identity_roles[name]) > 0 }
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

data "azuread_group" "lab" {
  for_each  = toset(data.azuread_groups.lab.object_ids)
  object_id = each.value
}

# All lab-* groups; see entra_group_ids. Group names in openziti.yaml must follow this prefix.
data "azuread_groups" "lab" {
  display_name_prefix = "lab-"
  security_enabled    = true
}

check "entra_groups_exist" {
  assert {
    condition     = length(local.missing_entra_groups) == 0
    error_message = "Entra groups not found yet, so their Dial policies are skipped or only partly applied until the entra component creates them: ${join(", ", local.missing_entra_groups)}"
  }
}
