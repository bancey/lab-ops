variable "target_nodes" {
  type        = list(string)
  description = "List of nodes to deploy VMs to."
  default     = []
}

variable "images" {
  type = map(object({
    file_name = optional(string)
    url       = string
  }))
}
