variable "target_node" {
  type        = string
  description = "The Proxmox node to deploy the COntainer to."
}

variable "ct_name" {
  type        = string
  description = "The name of the container."
}

variable "ct_description" {
  type        = string
  description = "The description of the container."
}

variable "cpu_cores" {
  type        = number
  description = "The number of CPU cores."
}

variable "memory" {
  type        = number
  description = "The amount of RAM."
}

variable "ip_address" {
  type        = string
  description = "IP Address of the Container."
}

variable "image_id" {
  type        = string
  description = "ID of the image to use for the LXC Container."
}

variable "image_type" {
  type        = string
  description = "The Type of the OS of the image."
}

variable "password" {
  type        = string
  description = "The password of the root user must be in a sha512crypt format."
  sensitive   = true
}
