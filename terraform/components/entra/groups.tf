resource "azuread_group" "this" {
  for_each                = local.groups
  display_name            = each.key
  description             = lookup(each.value, "description", null)
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]

  lifecycle {
    # Membership is managed by azuread_group_member below, not by this resource.
    ignore_changes = [members]
  }
}

data "azuread_user" "member" {
  for_each            = local.group_member_upns
  user_principal_name = each.value
}

resource "azuread_group_member" "this" {
  for_each         = local.group_members
  group_object_id  = azuread_group.this[each.value.group].object_id
  member_object_id = data.azuread_user.member[each.value.upn].object_id
}
