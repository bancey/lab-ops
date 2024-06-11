variable "target_nodes" {
  type        = list(string)
  description = "List of nodes to deploy VMs to."
  default     = []
}

variable "ubuntu_images" {
  type = list(object({
    ubuntu_version       = string
    ubuntu_image_version = string
  }))
  description = "Map of ubuntu images to download."
  default     = []
}
