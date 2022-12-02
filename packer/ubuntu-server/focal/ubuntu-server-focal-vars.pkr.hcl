proxmox_api_url = "https://192.168.80.11:8006/api2/json"
proxmox_api_token_id = "$(Wanda-Proxmox-Token-ID)"
proxmox_api_token_secret = "$(Wanda-Proxmox-Token-Secret)"
node = "wanda"
vm_id = 901
vm_name = "ubuntu-focal-template"
template_description = "Ubuntu 20.04 (Focal) Server Template"
iso_url = "https://releases.ubuntu.com/20.04/ubuntu-20.04.3-live-server-amd64.iso"
iso_checksum = "f8e3086f3cea0fb3fefb29937ab5ed9d19e767079633960ccb50e76153effc98"
username = "$(VM-Template-Username)"
ssh_private_key_file = "$(System.DefaultWorkingDirectory)/packer_private_key"
http_directory = "packer/ubuntu-server/http"
files_directory = "packer/ubuntu-server/files"

boot_command = [
  "c",
  "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/' ",
  "<enter><wait>",
  "initrd /casper/initrd<enter><wait>",
  "boot<enter>"
]

primary_provisioner_commands = [
  "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
  "sudo rm /etc/ssh/ssh_host_*",
  "sudo truncate -s 0 /etc/machine-id",
  "sudo apt -y autoremove --purge",
  "sudo apt -y clean",
  "sudo apt -y autoclean",
  "sudo cloud-init clean",
  "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
  "sudo sync"
]

secondary_provisioner_commands = [
  "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"
]