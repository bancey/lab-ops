variable "target_nodes" {
  type        = list(string)
  description = "List of nodes to deploy VMs to."
  default     = []
}

variable "images" {
  type = map(object({
    content_type = optional(string, "iso")
    url          = string
  }))
  description = "Map of image names to urls to download."
  default     = {}
}

variable "containers" {
  type = map(object({
    node                = string
    ct_id               = number
    cpu_cores           = number
    memory              = number
    ip_address          = string
    gateway_ip_address  = string
    network_bridge_name = string
    vlan_tag            = optional(string)
    startup_order       = number
    startup_delay       = number
    ct_description      = string
    storage             = string
    image               = optional(string)
    image_type          = optional(string, "ubuntu")
  }))
  description = "Map containing information about LXC Containers to create in Proxmox."
}
