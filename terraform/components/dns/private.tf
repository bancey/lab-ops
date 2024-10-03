module "adguard_thanos" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.thanos
  }
}

module "adguard_gamora" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.gamora
  }
}