resource "ziti_edge_router_policy" "this" {
  for_each        = local.edge_router_policies
  name            = each.key
  edgerouterroles = each.value.edge_router_roles
  identityroles   = each.value.identity_roles
}

resource "ziti_service_edge_router_policy" "this" {
  for_each        = local.service_edge_router_policies
  name            = each.key
  edgerouterroles = each.value.edge_router_roles
  serviceroles    = each.value.service_roles
}

# RBAC lives here: Bind stays generic (home routers host everything), while each Dial policy
# grants an access tier on the services to the Entra groups named in entra_groups. Groups that
# don't exist yet are skipped (see interpolated-defaults.tf).
resource "ziti_service_policy" "this" {
  for_each      = local.active_service_policies
  name          = each.key
  type          = each.value.type
  identityroles = local.service_policy_identity_roles[each.key]
  serviceroles  = each.value.service_roles
}
