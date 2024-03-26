env                            = "prod"
gameservers_vnet_address_space = ["10.200.0.0/16"]
gameservers                    = {}

cloudflare_records = {
  "@" = {
    value   = "PublicIP"
    type    = "A"
    proxied = true
    ttl     = 1
  },
  "whales" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "request" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "plex" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "wf" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "pterodactyl" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  }
}

master_count = 1
node_count   = 4

virtual_machines = {
  scrypted = {
    node                = "wanda",
    vm_id               = 101,
    vm_description      = "VM to run Scrypted, a surveillance integration system.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.14.25/24",
    gateway_ip_address  = "10.151.14.1",
    network_bridge_name = "vmbr0",
    vlan_tag            = "-1",
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
  }
  test0 = {
    node                = "hela",
    vm_id               = 120,
    vm_description      = "Test VM.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.14.100/24",
    gateway_ip_address  = "10.151.14.1",
    network_bridge_name = "vmbr0",
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
  }
  test1 = {
    node                = "thor",
    vm_id               = 120,
    vm_description      = "Test VM.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.16.100/24",
    gateway_ip_address  = "10.151.16.1",
    network_bridge_name = "vmbr1",
    vlan_tag            = "16"
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
  }
  test2 = {
    node                = "loki",
    vm_id               = 120,
    vm_description      = "Test VM.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.15.25/24",
    gateway_ip_address  = "10.151.15.1",
    network_bridge_name = "vmbr1",
    vlan_tag            = "15"
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
  }
}

twingate_groups           = ["pve", "all"]
twingate_service_accounts = ["AzureDevOps"]
twingate_networks = {
  banceylab = {
    resources = {
      hela = {
        address = "10.151.14.12"
        alias   = "hela.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      thor = {
        address = "10.151.14.13"
        alias   = "thor.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      loki = {
        address = "10.151.14.14"
        alias   = "loki.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      wanda = {
        address = "10.151.14.11"
        alias   = "wanda.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      thanos = {
        address = "10.151.14.5"
        alias   = "thanos.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 53]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
    }
    connectors = ["banceylab-connector"]
  }
}

