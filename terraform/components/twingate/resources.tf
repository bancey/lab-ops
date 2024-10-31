resource "twingate_resource" "this" {
  for_each           = local.merged_resources
  name               = each.value.alias == null || each.value.alias == "" ? each.key : split(".", each.value.alias)[0]
  remote_network_id  = twingate_remote_network.this[each.value.twingate.network].id
  address            = each.value.record
  alias              = each.value.alias
  security_policy_id = data.twingate_security_policy.default.id

  protocols = each.value.twingate.protocols

  dynamic "access_group" {
    for_each = toset(each.value.twingate.access.groups)
    content {
      group_id           = twingate_group.this[access_group.value].id
      security_policy_id = data.twingate_security_policy.default.id
    }
  }

  dynamic "access_service" {
    for_each = toset(each.value.twingate.access.service_accounts)
    content {
      service_account_id = twingate_service_account.this[access_service.value].id
    }
  }

  is_active = lookup(each.value.twingate, "is_active", true)
}
