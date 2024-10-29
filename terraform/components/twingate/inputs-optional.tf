variable "twingate_groups" {
  type        = list(string)
  description = "List of groups to create in TwinGate."
  default     = []
}

variable "twingate_service_accounts" {
  type = map(object({
    trigger_credential_replace = optional(string, null)
  }))
  description = "Map of service accounts to create in TwinGate."
  default     = {}
}

variable "twingate_networks" {
  type = map(object({
    location   = optional(string, "ON_PREMISE")
    connectors = optional(list(string), [])
  }))
  description = "Map of networks to create in TwinGate."
  default     = {}
}

variable "dns_yaml_path" {
  type        = string
  description = "The path to the yaml file containing the DNS/Twingate resource config."
  default     = null
}

variable "twingate_resources" {
  type = map(object({
    alias  = optional(string)
    record = string
    twingate = object({
      access = object({
        groups           = list(string)
        service_accounts = list(string)
      })
      network = string
      protocols = object({
        allow_icmp = optional(bool, false)
        tcp = optional(object({
          policy = string
          ports  = optional(list(string))
        }), { policy = "DENY_ALL" })
        udp = optional(object({
          policy = string
          ports  = optional(list(string))
        }), { policy = "DENY_ALL" })
      })
    })
  }))
  description = "Map of resources to create in Twingate, this is in addition to resources defined within the dns configuration."
  default     = {}
}
