gameserver_name = "pteronode"
env             = "prod"

cloudflare_records = {
  "@" = {
    value   = "PublicIP"
    type    = "A"
    proxied = true
    ttl     = 1
  },
  "thor" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "tyr" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "loki" = {
    value   = "@"
    type    = "CNAME"
    proxied = true
    ttl     = 1
  },
  "wanda" = {
    value   = "@"
    type    = "CNAME"
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

