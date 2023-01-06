variable "cloudflare_cname_record_names" {
  type        = list(string)
  description = "The names for CNAME records to create in Cloudflare."
  default = [
    "thor",
    "tyr",
    "wanda",
    "portainer"
  ]
}
