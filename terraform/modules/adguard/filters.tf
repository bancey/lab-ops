resource "adguard_list_filter" "filters" {
  for_each  = var.adguard_filters
  name      = each.key
  url       = each.value.url
  enabled   = each.value.enabled
  whitelist = each.value.whitelist
}
