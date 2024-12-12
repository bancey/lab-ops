env                            = "test"
gameservers_vnet_address_space = ["10.100.0.0/16"]
gameservers                    = {}

cloud_vpn_gateway = {
  name = "lab-vpn"
  networking = {
    address_space                 = "10.151.190.0/24"
    gateway_subnet_address_prefix = "10.151.190.0/24"
  }
}
