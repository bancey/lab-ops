variable "location" {
  description = "Target Azure location to deploy resources into"
  type        = string
  default     = "uksouth"
}

variable "gameserver_count" {
  description = "The number of game servers to deploy"
  type        = number
  default     = 1
}
