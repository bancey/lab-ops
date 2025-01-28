variable "game_servers" {
  description = "Map of objects representing game servers to deploy"
  type = map(object({
    type                = optional(string, "pterodactyl")
    size                = optional(string, "Standard_D4as_v5")
    domain_name         = optional(string, null)
    publicly_accessible = optional(bool, false)
  }))
}

variable "game_server_vnet_address_space" {
  description = "The address space for the game servers virtual network"
  type        = list(string)
}

variable "game_server_vnet_peerings" {
  description = "Map of peerings to create between the game servers virtual network and other virtual networks."
  type = map(object({
    vnet_name                = string
    vnet_resource_group_name = string
  }))
  default = {}
}

variable "env" {
  description = "The name of the environment"
  type        = string
}
