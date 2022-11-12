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
  sensitive   = true
}

variable "pterodactyl_panel_ip" {
  description = "The IP of the Pterodactyl panel"
  type        = string
  sensitive   = true
}

variable "gameserver_ports" {
  description = "The ports to be used by gameservers and should be open to all traffic"
  type        = string
  sensitive   = true
}

variable "ovh_endpoint" {
  description = "The OVH API Endpoint to use."
  type        = string
  sensitive   = true
}

variable "ovh_application_key" {
  description = "The Application Key to use to authenticate to the OVH API."
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "The Application Secret to use to authenticate to the OVH API."
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "The Consumer Key to use to authenticate to the OVH API."
  type        = string
  sensitive   = true
}
