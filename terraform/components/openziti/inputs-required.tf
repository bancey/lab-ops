variable "openziti" {
  type = object({
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
    storage             = string
    disk_size           = number
    image               = string
    ansible_trigger     = string
    controller_address  = string
    test_identity_name  = string
    test_service_name   = string
    test_service_host   = string
    test_service_port   = number
  })
  description = "Configuration for the dedicated OpenZiti phase-1 VM and bootstrap variables."
}
