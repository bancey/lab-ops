variable "env" {
  description = "The name of the environment"
  type        = string
}

variable "tenant_id" {
  description = "The Entra ID tenant that holds the groups referenced from openziti.yaml."
  type        = string
}
