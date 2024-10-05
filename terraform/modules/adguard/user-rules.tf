resource "adguard_user_rules" "test" {
  count = length(var.adguard_user_rules) > 0 ? 1 : 0
  rules = var.adguard_user_rules
}