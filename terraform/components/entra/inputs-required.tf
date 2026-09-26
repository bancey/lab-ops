variable "env" {
  description = "The name of the environment"
  type        = string
}

variable "tenant_id" {
  description = "The Entra ID tenant to manage groups and app registrations in."
  type        = string
}
