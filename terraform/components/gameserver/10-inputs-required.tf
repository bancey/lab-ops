variable "gameserver_name" {
  description = "The name of the game server"
  type        = string
}

variable "env" {
  description = "The name of the environment"
  type        = string
}

variable "admin_access_ip" {
  description = "The IP to allow SSH connections from"
  type        = string
}
