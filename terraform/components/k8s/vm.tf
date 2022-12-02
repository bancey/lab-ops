resource "proxmox_vm_qemu" "your-vm" {
  target_node = "your-proxmox-node"
  vmid        = "0"
  name        = "master"
  onboot      = true
  startup     = "order=10"
  clone       = "ubuntu-jammy-template"
  agent       = 1
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  os_type     = "cloud-init"
  ipconfig0   = "ip=192.168.80.16/32,gw=192.168.80.1"

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }
}
