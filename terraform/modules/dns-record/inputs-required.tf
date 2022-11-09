variable "subdomain" {
  description = "The subdomain"
  type        = string
}

variable "record_type" {
  description = "The type of DNS record"
  type        = string
}

variable "ttl" {
  description = "The TTL of the DNS record"
  type        = string
}

variable "ip_address" {
  description = "The target IP address of the DNS record"
  type        = string
}
