module "adguard_thanos" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.thanos
  }

  adguard_rewrites   = local.adguard_rewrites
  adguard_filters    = var.adguard_filters
  adguard_user_rules = var.adguard_user_rules
}

module "adguard_gamora" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.gamora
  }

  adguard_rewrites   = local.adguard_rewrites
  adguard_filters    = var.adguard_filters
  adguard_user_rules = var.adguard_user_rules
}
