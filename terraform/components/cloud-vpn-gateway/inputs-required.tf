variable "env" {
  description = "The name of the environment"
  type        = string
}

variable "cloud_vpn_gateway" {
  type = object({
    name                         = string
    active                       = optional(bool, true)
    existing_resource_group_name = optional(string)
    tags                         = optional(map(string))
    networking = object({
      address_space                 = string
      gateway_subnet_address_prefix = string
    })
  })
  description = "Object describing the configuration for the VPN Gateway and associated resources."
}
