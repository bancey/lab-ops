output "primary_mac_address" {
  value = length(proxmox_virtual_environment_vm.vm.mac_addresses) > 1 ? proxmox_virtual_environment_vm.vm.mac_addresses[1] : proxmox_virtual_environment_vm.vm.mac_addresses[0]
  description = "Returns the 'primary' mac address, if the guest agent is running this will return several mac addresses, if not it will return the hardware mac address."
}
