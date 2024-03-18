resource "twingate_remote_network" "this" {
  for_each = var.twingate_networks
  name     = each.key
  location = each.value.location
}