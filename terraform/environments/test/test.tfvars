env                            = "test"
game_server_vnet_address_space = ["10.151.191.0/24"]
game_servers                    = {}

cloud_vpn_gateway = {
  name = "lab-vpn"
  networking = {
    address_space                 = "10.151.190.0/24"
    gateway_subnet_address_prefix = "10.151.190.0/24"
  }
}
