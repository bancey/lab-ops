env                            = "prod"
game_server_vnet_address_space = ["10.151.201.0/24"]
game_server_vnet_peerings = {
  #prod-vpn = {
  #  vnet_name                = "lab-vpn-vpn-prod"
  #  vnet_resource_group_name = "lab-vpn-prod-rg"
  #}
}
game_servers = {}

cloudflare_records = {}

kubernetes_virtual_machines = {
  wanda = {
    target_nodes    = ["wanda"]
    ansible_trigger = "20_05_2025_0822"
    cluster_cidr    = "10.42.0.0/16"
    service_cidr    = "10.43.0.0/16"
    bgp_as          = 64601
    disk_size       = 20
    image           = "jammy-server-cloudimg-amd64.img"
    master = {
      count              = 1
      cidr               = "10.151.15.8/29"
      gateway_ip_address = "10.151.15.1"
      vlan_tag           = "15"
    }
    worker = {
      count              = 4
      cidr               = "10.151.15.16/29"
      gateway_ip_address = "10.151.15.1"
      vlan_tag           = "15"
    }
  }
  tiny = {
    target_nodes          = ["hela", "loki", "thor"]
    ansible_trigger       = "13_05_2025_2225"
    k3s_etcd_datastore    = true
    disk_size             = 100
    image                 = "jammy-server-cloudimg-amd64.img"
    cluster_cidr          = "10.44.0.0/16"
    service_cidr          = "10.45.0.0/16"
    bgp_as                = 64602
    load_balancer_address = "10.151.16.200"
    master = {
      count              = 3
      cidr               = "10.151.16.8/29"
      gateway_ip_address = "10.151.16.1"
      vlan_tag           = "16"
    }
    worker = {
      count              = 3
      cidr               = "10.151.16.16/29"
      gateway_ip_address = "10.151.16.1"
      vlan_tag           = "16"
    }
  }
}

virtual_machines = {
  wings-thor = {
    node                = "thor"
    vm_id               = 500
    vm_description      = "Thor Wings node"
    cpu_cores           = 4
    memory              = 12288
    ip_address          = "10.151.14.100"
    gateway_ip_address  = "10.151.14.1"
    network_bridge_name = "vmbr0"
    startup_order       = 1
    startup_delay       = 1
    storage             = "local-lvm"
    disk_size           = 64
    image               = "jammy-server-cloudimg-amd64.img"
  }
}

containers = {
  longhorn-backup = {
    node                = "wanda"
    ct_id               = 599
    ct_description      = "Longhorn Backup LXC Container. Used to backup Longhorn volumes."
    cpu_cores           = 4
    memory              = 4096
    ip_address          = "10.151.14.199"
    gateway_ip_address  = "10.151.14.1"
    network_bridge_name = "vmbr1"
    vlan_tag            = "14"
    startup_order       = 0
    startup_delay       = 0
    storage             = "local-lvm"
  }
  haproxy0 = {
    node                = "hela"
    ct_id               = 250
    ct_description      = "Hela HAProxy LXC Container. Load Balances services including K8S control plane."
    cpu_cores           = 1
    memory              = 512
    ip_address          = "10.151.16.201"
    gateway_ip_address  = "10.151.16.1"
    network_bridge_name = "vmbr1"
    vlan_tag            = "16"
    startup_order       = 0
    startup_delay       = 0
    storage             = "local-lvm"
  }
  haproxy1 = {
    node                = "loki"
    ct_id               = 251
    ct_description      = "Loki HAProxy LXC Container. Load Balances services including K8S control plane."
    cpu_cores           = 1
    memory              = 512
    ip_address          = "10.151.16.202"
    gateway_ip_address  = "10.151.16.1"
    network_bridge_name = "vmbr1"
    vlan_tag            = "16"
    startup_order       = 0
    startup_delay       = 0
    storage             = "local-lvm"
  }
  haproxy2 = {
    node                = "thor"
    ct_id               = 252
    ct_description      = "Thor HAProxy LXC Container. Load Balances services including K8S control plane."
    cpu_cores           = 1
    memory              = 512
    ip_address          = "10.151.16.203"
    gateway_ip_address  = "10.151.16.1"
    network_bridge_name = "vmbr1"
    vlan_tag            = "16"
    startup_order       = 0
    startup_delay       = 0
    storage             = "local-lvm"
  }
}

ansible = {
  "haproxy" = {
    nodes    = ["hela", "loki", "thor"]
    playbook = "haproxy.yaml"
    secrets = {
      "keepalived_pass" = "keepalived-pass"
    }
  }
  "wings-local" = {
    nodes    = ["hela", "loki", "thor"]
    playbook = "wings-node.yaml"
    secrets = {
      "cloudflare_api_token" = "Cloudflare-Lab-API-Token"
    }
  }
}

images = {
  "jammy-server-cloudimg-amd64.img" = { url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" }
}

twingate_groups = ["pve", "all", "tiny_k8s", "wanda_k8s", "pterodactyl"]
twingate_service_accounts = {
  "AzureDevOps" = {}
  "Pterodactyl" = {
    trigger_credential_replace = "03/09/24@1925"
  }
}
twingate_networks = {
  banceylab = {
    connectors = ["banceylab-connector", "banceylab-connector-2"]
  }
}

twingate_resources = {
  "banceylab-tiny-k8s" = {
    record = "10.151.16.0/24"
    twingate = {
      network = "banceylab"
      access = {
        groups           = ["tiny_k8s", "all"]
        service_accounts = ["AzureDevOps"]
      }
      protocols = {
        tcp = {
          policy = "RESTRICTED"
          ports  = ["22", "6443"]
        }
      }
    }
  }
  "banceylab-wanda-k8s" = {
    record = "10.151.15.0/24"
    twingate = {
      network = "banceylab"
      access = {
        groups           = ["wanda_k8s", "all"]
        service_accounts = ["AzureDevOps"]
      }
      protocols = {
        tcp = {
          policy = "RESTRICTED"
          ports  = ["22", "6443"]
        }
      }
    }
  }
  "test-vms" = {
    record = "10.151.14.192/27"
    twingate = {
      network = "banceylab"
      access = {
        groups           = ["all"]
        service_accounts = ["AzureDevOps"]
      }
      protocols = {
        tcp = {
          policy = "RESTRICTED"
          ports  = ["22", "443", "80"]
        }
      }
    }
  }
}

adguard_filters = {
  "AdGuard DNS filter" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
  }
  "AWAvenue Ads Rule" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_53.txt"
  }
  "1Hosts (mini)" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_38.txt"
  }
  "1Hosts (Lite)" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_24.txt"
  }
  "Dan Pollock's List" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt"
  }
  "HaGeZi's Normal Blocklist" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_34.txt"
  }
  "HaGeZi's Pro Blocklist" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt"
  }
  "HaGeZi's Pro++ Blocklist" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_51.txt"
  }
  "OISD Blocklist Small" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt"
  }
  "OISD Blocklist Big" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_27.txt"
  }
  "Steven Black's List" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt"
  }
  "Peter Lowe's Blocklist" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"
  }
  "HaGeZi's Ultimate Blocklist" = {
    url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_49.txt"
  }
}

adguard_user_rules = [
  "@@||whattoexpect.com^$important",
  "@@||analytics.twingate.com^$important",
  "@@||msmetrics.ws.sonos.com^$important",
  "@@||graph.facebook.com^$important",
  "@@||b-graph.facebook.com^$important",
  "@@||web.facebook.com^$important",
  "@@||graph.instagram.com^$important",
  "@@||e.reddit.com^$important",
  "@@||alb.reddit.com^$important",
  "@@||applicationinsights.azure.com^$important",
  "@@||api.loganalytics.io^$important",
  "@@||dynatrace.com^$important",
]

cloud_vpn_gateway = {
  name   = "lab-vpn"
  active = false
  networking = {
    address_space                 = "10.151.200.0/24"
    gateway_subnet_address_prefix = "10.151.200.0/24"
  }
}
