module "adguard_thanos" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.thanos
  }

  adguard_rewrites = local.adguard_rewrites
}

module "adguard_gamora" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.gamora
  }

  adguard_rewrites = local.adguard_rewrites
}