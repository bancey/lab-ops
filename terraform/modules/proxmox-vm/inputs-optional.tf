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

variable "cpu_architecture" {
  type        = string
  description = "The Architecture to use for the CPU. Defaults to x86_64"
  default     = "x86_64"
}

variable "cpu_type" {
  type        = string
  description = "The type to use for the CPU. Defaults to host."
  default     = "host"
}

variable "gateway_ip_address" {
  type        = string
  description = "The IP address of the gateway."
  default     = "192.168.80.1"
}

variable "network_bridge_name" {
  type        = string
  description = "The name of the network bridge to use."
  default     = "vmbr0"
}

variable "vlan_tag" {
  type        = string
  description = "The VLAN tag to apply to the network interface."
  default     = "-1"
}

variable "resource_pool" {
  type        = string
  description = "The resource pool to use."
  default     = null
}

variable "storage" {
  type        = string
  description = "The storage pool to use."
  default     = "local-lvm"
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to the VM."
  default     = []
}

variable "domain" {
  type        = string
  description = "The domain the VM is in."
  default     = "heimelska.co.uk"
}

variable "disk_size" {
  type        = number
  description = "The size of the disk in GB."
  default     = 8
}
