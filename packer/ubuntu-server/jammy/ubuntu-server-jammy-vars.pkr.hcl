proxmox_api_url          = "https://10.151.14.11:8006/api2/json"
proxmox_api_token_id     = "$(Wanda-Proxmox-Token-ID)"
proxmox_api_token_secret = "$(Wanda-Proxmox-Token-Secret)"
node                     = "wanda"
template_description     = "Ubuntu 22.04 (Jammy) Server Template"
iso_file                 = "local:iso/ubuntu-22.04.2-live-server-amd64.iso"
#iso_url                  = "https://www.mirrorservice.org/sites/releases.ubuntu.com/22.04.2/ubuntu-22.04.2-live-server-amd64.iso"
iso_checksum             = "5e38b55d57d94ff029719342357325ed3bda38fa80054f9330dc789cd2d43931"
username                 = "$(VM-Template-Username)"
ssh_private_key_file     = "$(System.DefaultWorkingDirectory)/packer_private_key"
http_directory           = "packer/ubuntu-server/http"
files_directory          = "packer/ubuntu-server/files"

boot_command = [
  "e<wait>",
  "<down><down><down><end>",
  "<bs><bs><bs><bs><wait>",
  "autoinstall ip=dhcp net.ifnames=0 biosdevname=0 ipv6.disable=1 ",
  "ds=nocloud-net\\;s=http://10.151.11.119:{{ .HTTPPort }}/ ",
  "---<wait><f10><wait>"
]

primary_provisioner_commands = [
  "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
  "sudo rm /etc/ssh/ssh_host_*",
  "sudo truncate -s 0 /etc/machine-id",
  "sudo apt-get -y autoremove --purge",
  "sudo apt-get -y clean",
  "sudo apt-get -y autoclean",
  "sudo cloud-init clean",
  "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
  "sudo sync"
]

secondary_provisioner_commands = [
  "sudo cp /tmp/files/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"
]