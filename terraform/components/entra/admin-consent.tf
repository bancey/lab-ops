# Optional: pre-consent the delegated Graph scopes so users are never shown a consent prompt.
# Off by default because it needs DelegatedPermissionGrant.ReadWrite.All on the deploying service
# principal, which the least-privilege permission set in docs/sso-operations.md does not include.
data "azuread_service_principal" "msgraph" {
  count     = var.grant_admin_consent ? 1 : 0
  client_id = local.graph_app_id
}

resource "azuread_service_principal_delegated_permission_grant" "this" {
  for_each = {
    for name, app in local.applications : name => app
    if var.grant_admin_consent
  }
  service_principal_object_id          = azuread_service_principal.this[each.key].object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph[0].object_id
  claim_values                         = lookup(each.value, "graph_scopes", local.default_graph_scopes)
}
