variable "virtual_machines" {
  type = map(object({ node = string, vm_id = number, cpu_cores = number, memory = number, ip_address = string, startup_order = number, startup_delay = number, vm_description = string, cname_required = bool }))
  description = "Map containing information about Virtual Machines to create in Proxmox."
}
