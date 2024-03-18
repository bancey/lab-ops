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

twingate_groups           = ["pve", "all"]
twingate_service_accounts = ["AzureDevOps"]
twingate_networks = {
  banceylab = {
    resources = {
      hela = {
        address = "hela.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          group_names      = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      thor = {
        address = "thor.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          group_names      = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      loki = {
        address = "loki.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          group_names      = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      wanda = {
        address = "wanda.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 8006]
          }
        }
        access = {
          group_names      = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      thanos = {
        address = "thanos.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 53]
          }
        }
        access = {
          group_names      = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
    }
    connectors = ["banceylab-connector"]
  }
}

