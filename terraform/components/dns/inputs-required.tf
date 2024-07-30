variable "cloudflare_records" {
  type        = map(object({ type = string, value = string, proxied = bool, ttl = number, zone = optional(string, "lab") }))
  description = "A map of DNS records."
}
