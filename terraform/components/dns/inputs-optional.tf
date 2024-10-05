variable "dns_yaml_path" {
  type        = string
  description = "The path to the yaml file containing the DNS/Twingate resource config."
  default     = null
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

variable "adguard_user_rules" {
  type        = list(string)
  description = "List of rules to apply to AdGuard home."
  default     = []
}
