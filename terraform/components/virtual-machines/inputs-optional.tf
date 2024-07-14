variable "target_nodes" {
  type        = list(string)
  description = "List of nodes to deploy VMs to."
  default     = []
}

variable "images" {
  type        = map(string)
  description = "Map of image names to urls to download."
  default     = {}
}
