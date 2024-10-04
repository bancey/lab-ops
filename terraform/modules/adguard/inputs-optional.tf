variable "adguard_config" {
  type = object({
    filtering = optional(object({
      enabled         = optional(bool, true)
      update_interval = optional(number, 24)
    }), {})
    query_log = optional(object({
      enabled             = optional(bool, true)
      interval            = optional(number, 2160)
      anonymize_client_ip = optional(bool, false)
    }), {})
    stats = optional(object({
      enabled  = optional(bool, true)
      interval = optional(number, 168)
    }), {})
    dns = optional(object({
      protection_enabled = optional(bool, true)
      upstream_dns       = optional(list(string), ["https://dns10.quad9.net/dns-query"])
      upstream_mode      = optional(string, "load_balance")
      fallback_dns       = optional(list(string), ["https://1.1.1.1/dns-query", "https://1.0.0.1/dns-query"])
      bootstrap_dns      = optional(list(string), ["1.1.1.1", "1.0.0.1"])
      rate_limit         = optional(number, 30)
    }), {})
  })
  description = "Object describing the configuration of the AdGuard home instance."
  default     = {}
}

variable "adguard_filters" {
  type = map(object({
    url       = string
    enabled   = optional(bool, true)
    whitelist = optional(bool, false)
  }))
  description = "Map of objects describing the filters to apply to the Adguard home instance."
  default     = {}
}

variable "adguard_rewrites" {
  type        = map(string)
  description = "Map of domains to answers to configure as rewrites in Adguard Home."
  default     = {}
}
