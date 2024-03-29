variable "target_node" {
  type        = string
  description = "The Proxmox node to deploy the VM to."
}

variable "vm_name" {
  type        = string
  description = "The name of the virtual machine."
}

variable "vm_description" {
  type        = string
  description = "The description of the virtual machine."
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
  description = "IP Address of the VM."
}

variable "username" {
  type        = string
  description = "The name of the administrator of the VM."
}

variable "password" {
  type        = string
  description = "The password of the administrator of the VM must be in a sha512crypt format."
  sensitive   = true
}

variable "image_id" {
  type        = string
  description = "ID of the image to use for the VM."
}
