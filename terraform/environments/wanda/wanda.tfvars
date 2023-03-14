master_count = 1
node_count   = 4

virtual_machines = {
  migration = {
    node                = "wanda",
    vm_id               = 101,
    vm_description      = "Temporary migration VM to allow me to decommission a physical host.",
    cpu_cores           = 4,
    memory              = 16384,
    ip_address          = "10.151.14.21",
    gateway_ip_address  = "10.151.14.1",
    network_bridge_name = "vmbr0",
    vlan_tag            = "-1",
    startup_order       = 1,
    startup_delay       = 1,
    cname_required      = false
  },
  #wings1 = {
  #  node                = "wanda",
  #  vm_id               = 300,
  #  vm_description      = "A Pterodactyl node.",
  #  cpu_cores           = 2,
  #  memory              = 12288,
  #  ip_address          = "10.151.14.30",
  #  gateway_ip_address  = "10.151.14.1",
  #  network_bridge_name = "vmbr0",
  #  vlan_tag            = "-1",
  #  startup_order       = 1,
  #  startup_delay       = 1,
  #  cname_required      = true
  #}
}
