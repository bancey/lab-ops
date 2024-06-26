variable "twingate_groups" {
  type        = list(string)
  description = "List of groups to create in TwinGate."
  default     = []
}

variable "twingate_service_accounts" {
  type        = list(string)
  description = "List of service accounts to create in TwinGate."
  default     = []
}

variable "twingate_networks" {
  type = map(object({
    location = optional(string, "ON_PREMISE")
    resources = map(object({
      address   = string
      alias     = optional(string)
      is_active = optional(bool, true)
      protocols = object({
        allow_icmp = optional(bool, false)
        tcp = optional(object({
          policy = optional(string, "DENY_ALL")
          ports  = optional(list(number), [])
        }), {})
        udp = optional(object({
          policy = optional(string, "DENY_ALL")
          ports  = optional(list(number), [])
        }), {})
      })
      access = object({
        groups           = list(string)
        service_accounts = optional(list(string), [])
      })
    }))
    connectors = optional(list(string), [])
  }))
  description = "Map of networks to create in TwinGate."
  default     = {}
}
