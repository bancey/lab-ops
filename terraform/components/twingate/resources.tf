resource "twingate_resource" "this" {
  for_each          = { for resource in local.flattened_resources : resource.key => resource }
  name              = each.value.resource_key
  remote_network_id = twingate_remote_network.this[each.value.network_key].id
  address           = each.value.resource.address

  protocols = each.value.resource.protocols

  access = {
    group_ids           = [for group in each.value.resource.access.groups : twingate_group.this[group].id]
    service_account_ids = [for service_account in each.value.resource.access.service_accounts : twingate_service_account.this[service_account].id]
  }

  is_active = each.value.resource.is_active
}