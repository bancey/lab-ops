master_count = 1
node_count   = 4

virtual_machines = {
  scrypted = {
    node                = "wanda",
    vm_id               = 101,
    vm_description      = "VM to run Scrypted, a surveillance integration system.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.14.25",
    gateway_ip_address  = "10.151.14.1",
    network_bridge_name = "vmbr0",
    vlan_tag            = "-1",
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
  },
}
