variable "master_cidr" {
  type        = string
  description = "The IPv4 address of the master node."
  default     = "192.168.80.64/29"
}

variable "master_count" {
  type        = number
  description = "The number of master nodes to create."
  default     = 1
}

variable "nodes_cidr" {
  type        = string
  description = "The IPv4 address of the first worker node."
  default     = "192.168.80.72/29"
}

variable "node_count" {
  type        = number
  description = "The number of worker nodes to create."
  default     = 2
}