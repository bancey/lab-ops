variable "gameserver_existing_resource_group_name" {
  description = "Name of an existing resourcegroup to deploy resources into"
  type        = string
  default     = null
}

variable "location" {
  description = "Target Azure location to deploy resources into"
  type        = string
  default     = "uksouth"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = null
}

variable "gameserver_vnet_address_space" {
  description = "The address space of the virtual network"
  type        = list(string)
  default     = ["10.100.0.0/16"]
}
