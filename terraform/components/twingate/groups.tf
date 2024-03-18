resource "twingate_group" "this" {
  for_each = toset(var.twingate_groups)
  name     = each.value
}
