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
  }
}
