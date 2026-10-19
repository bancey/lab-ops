# Each service gets an intercept.v1 (what clients dial) and a host.v1 (where the hosting router
# sends traffic), named <service>-intercept and <service>-host.
#
# A service without host_address forwards to whatever the client dialled, limited to its own
# intercept_addresses (hostnames, which the home routers resolve, or CIDRs). A service with several
# ports forwards the dialled port the same way, so host_port only applies to a single port.
resource "ziti_intercept_v1_config" "this" {
  for_each  = local.services
  name      = "${each.key}-intercept"
  addresses = each.value.intercept_addresses
  protocols = lookup(each.value, "protocols", ["tcp"])
  port_ranges = [for p in local.service_ports[each.key] : {
    low  = p
    high = p
  }]
}

resource "ziti_host_v1_config" "this" {
  for_each = local.services
  name     = "${each.key}-host"
  protocol = lookup(each.value, "host_protocol", "tcp")
  # null rather than false when unused, so services with a fixed address and port plan no change
  address           = try(each.value.host_address, null)
  forward_address   = can(each.value.host_address) ? null : true
  allowed_addresses = can(each.value.host_address) ? null : each.value.intercept_addresses

  port         = length(local.service_ports[each.key]) == 1 ? try(each.value.host_port, local.service_ports[each.key][0]) : null
  forward_port = length(local.service_ports[each.key]) == 1 ? null : true
  allowed_port_ranges = length(local.service_ports[each.key]) == 1 ? null : [for p in local.service_ports[each.key] : {
    low  = p
    high = p
  }]
}

resource "ziti_service" "this" {
  for_each        = local.services
  name            = each.key
  role_attributes = each.value.role_attributes
  configs = [
    ziti_intercept_v1_config.this[each.key].id,
    ziti_host_v1_config.this[each.key].id,
  ]
}
