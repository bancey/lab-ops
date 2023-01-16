variable "vm_id" {
  type        = string
  description = "The ID of the VM, defaults to 0 (proxmox will pick the next available ID)"
  default     = "0"
}

variable "start_on_boot" {
  type        = bool
  description = "Should the VM start on node powerup?"
  default     = true
}

variable "startup_order" {
  type        = number
  description = "The order to start the VM in."
  default     = 10
}

variable "startup_delay" {
  type        = number
  description = "The delay in seconds to start the VM with."
  default     = 120
}

variable "qemu_agent_installed" {
  type        = number
  description = "Is the QEMU agent installed?"
  default     = 1
}

variable "cpu_sockets" {
  type        = number
  description = "The number of CPU sockets."
  default     = 1
}

variable "gateway_ip_address" {
  type        = string
  description = "The IP address of the gateway."
  default     = "192.168.80.1"
}
