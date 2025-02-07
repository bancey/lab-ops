variable "source_address_prefix" {
  type        = string
  description = "The address prefix to allow traffic from"
  default     = "10.0.0.0/8"
}

variable "publicly_accessible" {
  type        = bool
  description = "Whether the game server should be publicly accessible"
  default     = false
}
