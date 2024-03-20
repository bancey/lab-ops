variable "virtual_machines" {
  type = map(object({
    node                = string
    vm_id               = number
    cpu_cores           = number
    memory              = number
    ip_address          = string
    gateway_ip_address  = string
    network_bridge_name = string
    vlan_tag            = optional(string)
    startup_order       = number
    startup_delay       = number
    vm_description      = string
    cname_required      = optional(bool, false)
    storage             = string
  }))
  description = "Map containing information about Virtual Machines to create in Proxmox."
}
