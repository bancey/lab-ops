env                            = "prod"
gameservers_vnet_address_space = ["10.200.0.0/16"]
gameservers = {
  wings = {}
}

cloudflare_records = {}

kubernetes_virtual_machines = {
  wanda = {
    target_nodes     = ["wanda"]
    ansible_trigger  = "30_07_2024_0920"
    metallb_ip_range = "10.151.15.50-10.151.15.100"
    disk_size        = 20
    image            = "jammy-server-cloudimg-amd64.img"
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
    ansible_trigger       = "30_07_2024_0940"
    k3s_etcd_datastore    = true
    disk_size             = 100
    image                 = "jammy-server-cloudimg-amd64.img"
    metallb_ip_range      = "10.151.16.50-10.151.16.100"
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

virtual_machines = {}

containers = {
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

