module "adguard_thanos" {
  source = "../../modules/adguard"
  providers = {
    adguard = adguard.thanos
  }

  adguard_rewrites   = local.adguard_rewrites
  adguard_filters    = var.adguard_filters
  adguard_user_rules = var.adguard_user_rules

  adguard_config = {
    dns = {
      upstream_dns = ["https://dns10.quad9.net/dns-query", "[/*.home.bancey.xyz/]10.151.14.1"]
    }
  }
}

# My Raspberry Pi died
# module "adguard_gamora" {
#   source = "../../modules/adguard"
#   providers = {
#     adguard = adguard.gamora
#   }
# 
#   adguard_rewrites   = local.adguard_rewrites
#   adguard_filters    = var.adguard_filters
#   adguard_user_rules = var.adguard_user_rules
#   adguard_config = {
#     dns = {
#       upstream_dns = ["https://dns10.quad9.net/dns-query", "[/*.home.bancey.xyz/]10.151.14.1"]
#     }
#   }
# }
removed {
  from = module.adguard_gamora
  lifecycle {
    destroy = false
  }
}
