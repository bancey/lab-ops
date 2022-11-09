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
