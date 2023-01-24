variable "master_cidr" {
  type        = string
  description = "The IPv4 address of the master node."
  default     = "10.151.14.32/30"
}

variable "master_gateway_ip_address" {
  type = string
  description = "The IPv4 address of the master's gateway."
  default = "10.151.14.1"
}

variable "master_count" {
  type        = number
  description = "The number of master nodes to create."
  default     = 1
}

variable "node_cidr" {
  type        = string
  description = "The IPv4 address of the first worker node."
  default     = "10.151.14.36/30"
}

variable "node_gateway_ip_address" {
  type = string
  description = "The IPv4 address of the node's gateway."
  default = "10.151.14.1"
}

variable "node_count" {
  type        = number
  description = "The number of worker nodes to create."
  default     = 2
}