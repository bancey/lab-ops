resource "proxmox_vm_qemu" "vm" {
  target_node = var.target_node
  vmid        = var.vm_id
  name        = var.vm_name
  desc        = var.vm_description
  onboot      = var.start_on_boot
  startup     = "order=${var.startup_order},up=${var.startup_delay}"
  clone       = "ubuntu-jammy-template"
  agent       = var.qemu_agent_installed
  cores       = var.cpu_cores
  sockets     = var.cpu_sockets
  cpu         = "host"
  memory      = var.memory
  os_type     = "cloud-init"
  ipconfig0   = "ip=${var.ip_address}/24,gw=${var.gateway_ip_address}"

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      disk
    ]
  }
}
