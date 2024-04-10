resource "twingate_resource" "this" {
  for_each          = { for resource in local.flattened_resources : resource.key => resource }
  name              = each.value.resource_key
  remote_network_id = twingate_remote_network.this[each.value.network_key].id
  address           = each.value.resource.address
  alias             = each.value.resource.alias

  protocols = each.value.resource.protocols

  dynamic "access_group" {
    for_each = toset(each.value.resource.access.groups)
    content {
      group_id           = twingate_group.this[access_group.value].id
      security_policy_id = data.twingate_security_policy.default.id
    }
  }

  dynamic "access_service" {
    for_each = toset(each.value.resource.access.service_accounts)
    content {
      service_account_id = twingate_service_account.this[access_service.value].id
      security_policy_id = data.twingate_security_policy.default.id
    }
  }

  is_active = each.value.resource.is_active
}