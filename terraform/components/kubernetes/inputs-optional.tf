variable "master_cidr" {
  type        = string
  description = "The IPv4 address of the master node."
  default     = "10.151.15.2/28"
}

variable "master_gateway_ip_address" {
  type        = string
  description = "The IPv4 address of the master's gateway."
  default     = "10.151.15.1"
}

variable "master_count" {
  type        = number
  description = "The number of master nodes to create."
  default     = 1
}

variable "node_cidr" {
  type        = string
  description = "The IPv4 address of the first worker node."
  default     = "10.151.15.16/28"
}

variable "node_gateway_ip_address" {
  type        = string
  description = "The IPv4 address of the node's gateway."
  default     = "10.151.15.1"
}

variable "node_count" {
  type        = number
  description = "The number of worker nodes to create."
  default     = 2
}

variable "network_bridge_name" {
  type        = string
  description = "The name of the network bridge to use."
  default     = "vmbr1"
}

variable "vlan_tag" {
  type        = string
  description = "The VLAN tag to use."
  default     = "15"
}
