locals {
  entra_yaml_path = var.entra_yaml_path != null ? var.entra_yaml_path : "${path.cwd}/../../environments/${var.env}/entra.yaml"
  entra           = yamldecode(file(local.entra_yaml_path))

  groups       = lookup(local.entra, "groups", {})
  applications = lookup(local.entra, "applications", {})

  # One entry per (group, member) pair so membership can be managed as individual resources.
  # Deliberately not using azuread_group.members, which is authoritative and would remove anyone
  # added through the portal — handy in a household where access is sometimes granted in a hurry.
  group_members = {
    for pair in flatten([
      for group_name, group in local.groups : [
        for upn in lookup(group, "members", []) : {
          key   = "${group_name}/${upn}"
          group = group_name
          upn   = upn
        }
      ]
    ]) : pair.key => pair
  }

  group_member_upns = toset([for pair in local.group_members : pair.upn])

  # Applications that want a client secret generated and stored in Key Vault.
  app_secrets = {
    for name, app in local.applications : name => app
    if try(app.secret.enabled, false)
  }

  # Well-known Microsoft Graph identifiers. Hardcoded rather than looked up via
  # data.azuread_service_principal so the component works with only
  # Application.ReadWrite.OwnedBy, which cannot read the Graph service principal.
  graph_app_id = "00000003-0000-0000-c000-000000000000"

  graph_delegated_scope_ids = {
    "openid"         = "37f7f235-527c-4136-accd-4a02d197296e"
    "profile"        = "14dad69e-099b-42c9-810b-d002981feec1"
    "email"          = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"
    "offline_access" = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"
    "User.Read"      = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
  }

  default_graph_scopes = ["openid", "profile", "email", "offline_access"]

  # Claims required by every downstream consumer. The groups claim drives all authorization
  # (oauth2-proxy allowed_groups, Grafana role_attribute_path, Proxmox ACLs, K8s RBAC) and Entra
  # does not emit a usable email for accounts without a mail attribute unless upn is requested too.
  default_optional_claims = ["email", "upn"]

  # Secret lifetime, in days, per application. A 30 day grace period is added on top of the
  # rotation interval so a pipeline run that lands slightly late still finds a valid secret.
  secret_rotation_days = {
    for name, app in local.app_secrets : name => try(app.secret.rotation_days, 730)
  }

  # Key Vault secrets for an application are always the pair Entra-<prefix>-Client-ID and
  # Entra-<prefix>-Client-Secret, so scripts/sync-entra-secret.sh only needs the prefix.
  # Defaults to the yaml key with any leading "lab-" stripped: lab-oauth2-proxy -> oauth2-proxy.
  key_vault_prefixes = {
    for name, app in local.applications :
    name => lookup(app, "key_vault_prefix", trimprefix(name, "lab-"))
  }
}

data "azuread_client_config" "current" {}

data "azurerm_key_vault" "vault" {
  name                = "bancey-vault"
  resource_group_name = "btcs-common-prod"
}
