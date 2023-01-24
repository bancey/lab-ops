master_count = 3
node_count   = 3

virtual_machines = {
  migration = {
    node                = "wanda",
    vm_id               = 101,
    vm_description      = "Temporary migration VM to allow me to decommission a physical host.",
    cpu_cores           = 2,
    memory              = 8192,
    ip_address          = "10.151.14.21",
    gateway_ip_address  = "10.151.14.1",
    network_bridge_name = "vmbr0",
    startup_order       = 1,
    startup_delay       = 1,
    cname_required      = false
  },
  wings1 = {
    node                = "wanda",
    vm_id               = 300,
    vm_description      = "A Pterodactyl node.",
    cpu_cores           = 2,
    memory              = 12288,
    ip_address          = "10.151.15.20",
    gateway_ip_address  = "10.151.15.1",
    network_bridge_name = "vmbr1",
    vlan_tag            = "15",
    startup_order       = 1,
    startup_delay       = 1,
    cname_required      = true
  },
  ado-agents = {
    node                = "wanda",
    vm_id               = 301,
    vm_description      = "A VM for Azure DevOps agents.",
    cpu_cores           = 2,
    memory              = 4096,
    ip_address          = "10.151.15.21",
    gateway_ip_address  = "10.151.15.1",
    network_bridge_name = "vmbr1",
    vlan_tag            = "15",
    startup_order       = 1,
    startup_delay       = 1,
    cname_required      = false
  }
}
