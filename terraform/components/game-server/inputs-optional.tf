variable "location" {
  description = "Target Azure location to deploy resources into"
  type        = string
  default     = "uksouth"
}

variable "nsg_rules" {
  description = "Rule to apply to the network security group"
  type = map(object({
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = {}
}
