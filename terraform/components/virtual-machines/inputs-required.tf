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
    disk_size           = optional(number, 8)
    image               = optional(string)
  }))
  description = "Map containing information about Virtual Machines to create in Proxmox."
}

variable "kubernetes_virtual_machines" {
  type = map(object({
    target_nodes          = list(string)
    ansible_trigger       = optional(string)
    ansible_reboot_hosts  = optional(bool, false)
    disk_size             = optional(number)
    k3s_etcd_datastore    = optional(bool, false)
    load_balancer_address = optional(string, null)
    image                 = string
    master = object({
      count               = optional(number, 1)
      vm_id_start         = optional(number, 200)
      cidr                = string
      gateway_ip_address  = string
      vlan_tag            = string
      network_bridge_name = optional(string, "vmbr1")
      memory              = optional(number, 8192)
      cpu_cores           = optional(number, 4)
      disk_size           = optional(number)
    })
    worker = object({
      count               = optional(number, 3)
      vm_id_start         = optional(number, 220)
      cidr                = string
      gateway_ip_address  = string
      vlan_tag            = string
      network_bridge_name = optional(string, "vmbr1")
      memory              = optional(number, 4096)
      cpu_cores           = optional(number, 4)
      disk_size           = optional(number)
    })
  }))
  description = "Map containing information about Virtual Machines to create in Proxmox for Kubernetes."
}
