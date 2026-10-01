# Each service gets an intercept.v1 (what clients dial) and a host.v1 (where the hosting router
# sends traffic), named <service>-intercept and <service>-host.
resource "ziti_intercept_v1_config" "this" {
  for_each  = local.services
  name      = "${each.key}-intercept"
  addresses = each.value.intercept_addresses
  protocols = lookup(each.value, "protocols", ["tcp"])
  port_ranges = [{
    low  = each.value.port
    high = each.value.port
  }]
}

resource "ziti_host_v1_config" "this" {
  for_each = local.services
  name     = "${each.key}-host"
  protocol = lookup(each.value, "host_protocol", "tcp")
  address  = each.value.host_address
  port     = lookup(each.value, "host_port", each.value.port)
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
