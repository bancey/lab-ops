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
    target_nodes       = ["hela", "loki", "thor"]
    ansible_trigger    = "30_07_2024_0940"
    k3s_etcd_datastore = true
    disk_size          = 100
    image              = "jammy-server-cloudimg-amd64.img"
    metallb_ip_range   = "10.151.16.50-10.151.16.100"
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
  test0 = {
    node                = "hela",
    vm_id               = 120,
    vm_description      = "Test VM.",
    cpu_cores           = 4,
    memory              = 4096,
    ip_address          = "10.151.16.100",
    gateway_ip_address  = "10.151.16.1",
    network_bridge_name = "vmbr1",
    vlan_tag            = "16",
    startup_order       = 5,
    startup_delay       = 0,
    cname_required      = false
    storage             = "local-lvm"
    image               = "jammy-server-cloudimg-amd64.img"
  }
}

containers = {
  test-ct = {
    node                = "hela"
    ct_id               = 101
    ct_description      = "Test LXC Container"
    cpu_cores           = 1
    memory              = 512
    ip_address          = "10.151.16.101/24"
    gateway_ip_address  = "10.151.16.1"
    network_bridge_name = "vmbr1"
    vlan_tag            = "16"
    startup_order       = 5
    startup_delay       = 0
    storage             = "local-lvm"
    image               = "ubuntu-24.04-server-cloudimg-amd64-root.tar.xz"
    image_type          = "ubuntu"
  }
}

images = {
  "jammy-server-cloudimg-amd64.img" = { url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" }
  "ubuntu-24.04-server-cloudimg-amd64-root.tar.xz" = {
    url          = "https://mirrors.servercentral.com/ubuntu-cloud-images/releases/24.04/release-20240911/ubuntu-24.04-server-cloudimg-amd64-root.tar.xz"
    content_type = "vztmpl"
  }
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
    resources = {
      sonarr = {
        address = "10.151.16.50"
        alias   = "sonarr.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [443, 80]
          }
        }
        access = {
          groups           = ["wanda_k8s", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      dl = {
        address = "10.151.16.50"
        alias   = "dl.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [443, 80]
          }
        }
        access = {
          groups           = ["wanda_k8s", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      pterodactyl = {
        address = "10.151.16.50"
        alias   = "pterodactyl.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [8080, 443, 2022, 22]
          }
        }
        access = {
          groups           = ["pterodactyl", "all"]
          service_accounts = ["Pterodactyl"]

        }
      }
      wanda_k8s = {
        address = "10.151.15.0/24"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 443, 80]
          }
        }
        access = {
          groups           = ["wanda_k8s", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      tiny_k8s = {
        address = "10.151.16.0/24"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 443, 80]
          }
        }
        access = {
          groups           = ["tiny_k8s", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      tiny-pve = {
        address = "10.151.14.4"
        alias   = "tiny-pve.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [443]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
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
      wanda-mgmt = {
        address = "10.151.14.10"
        alias   = "wanda-mgmt.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [80, 443]
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
            ports  = [22, 53, 80]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
      gamora = {
        address = "10.151.14.6"
        alias   = "gamora.heimelska.co.uk"
        protocols = {
          tcp = {
            policy = "RESTRICTED"
            ports  = [22, 53, 80]
          }
        }
        access = {
          groups           = ["pve", "all"]
          service_accounts = ["AzureDevOps"]
        }
      }
    }
    connectors = ["banceylab-connector", "banceylab-connector-2"]
  }
}

