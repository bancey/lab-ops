variable "target_nodes" {
  type        = list(string)
  description = "List of nodes to deploy VMs to."
  default     = []
}
