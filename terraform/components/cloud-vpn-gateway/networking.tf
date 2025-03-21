module "networking" {
  count  = var.cloud_vpn_gateway.active ? 1 : 0
  source = "github.com/hmcts/terraform-module-azure-virtual-networking?ref=main"

  env                          = var.env
  product                      = "lab"
  common_tags                  = local.tags
  component                    = "vpn"
  existing_resource_group_name = local.resource_group_name

  vnets = {
    vpn = {
      address_space = [var.cloud_vpn_gateway.networking.address_space]
      subnets = {
        gateway = {
          name_override    = "GatewaySubnet"
          address_prefixes = [var.cloud_vpn_gateway.networking.gateway_subnet_address_prefix]
        }
      }
    }
  }

  route_tables = {}

  network_security_groups = {}
}

resource "azurerm_public_ip" "this" {
  count               = var.cloud_vpn_gateway.active ? 1 : 0
  name                = "${local.name}-public-ip"
  location            = var.location
  resource_group_name = local.resource_group_name

  allocation_method = "Dynamic"
  sku               = "Basic"
}
