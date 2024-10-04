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
