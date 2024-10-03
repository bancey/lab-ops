resource "adguard_rewrite" "rewrite" {
  for_each = var.adguard_rewrites
  domain   = each.key
  answer   = each.value
}
