variable "gameservers" {
  description = "Map of objects representing game servers to deploy"
  type = map(object({
    type        = optional(string, "pterodactyl")
    size        = optional(string, "Standard_D4as_v5")
    domain_name = optional(string, null)
  }))
}

variable "gameservers_vnet_address_space" {
  description = "The address space for the game servers virtual network"
  type        = list(string)
}

variable "env" {
  description = "The name of the environment"
  type        = string
}
