resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  vm_id       = var.vm_id
  description = var.vm_description
  pool_id     = var.resource_pool
  node_name   = var.target_node
  on_boot     = var.start_on_boot
  tags        = concat(["terraform"], var.tags)

  initialization {
    user_account {
      username = "bancey"
      keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4Vx68tO5cVPyWqC1l9eVrpFkLcQ7GV0tkdmR1Hx0k6wdtAGOFY4/20uI47wBFs0WAQwV1HR/hx8RSsCGVAuoqPqxYVPVAfyG38MyM70txdepKE2U2jRXq4tbwAfziOyllZFLSqP+uRWJ5rtffOV8rbDNOat8VBEIGIBsVlmtTHVwZfJvILyzI7pA4YLyweBFAJRBwVN/wP+Kylq4qs7khlwILTD/20/mLNWJGYqMRg58+rGWdJRhfLHgMV51oLpSDS7aHbhkVLjoVuLeqUARYfMdrPPf0lDWGlKAsRyIy1EO9Or7hk6BKTB5hA4G11vRmhoc9d9jcuoArOpUtKWQqoRU74GpSeGLmN2cUndUDrY4kEPzFORHBlKe5W1jt2rc7NRIhduOakrfRmzZGv3N2zoYin69XcRMaAwFXkCT9zIBSGYYvEoXLwX5DynmfHcCvl3/CPYRPX7oFQLMN0ghCWYCmibmTRLD0boB88hFGog/mun51L+aJyLvjBQHXaU6m5gTkJ3LUfkhZbbWPzhgyqLdw7MUfGF9LU5S8sEO71MxmiI76vLxfO/rpUoQpVG0oRde1TAwY7wgnWwFb7MmJ736+tLKzaFhshySrFodnRmcALzxkWYbNV+FI2Mz8ZdkTLvveJEmaiGdgf2B/RO2+VqX/QiCSJvFqcA6/eB35JQ== alexb@DESKTOP-CN2369K",
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDM6YQbnTJYYO6ANWiTwAU6LYLgwPkOu5sbDiUCYJt0dYgYUHzRa1cQsVE2ooLlmxwtHuL/8tjQtajL/HCaqr+XF41inGw3rz4cIXsQreRwudJNdP9Ba+2eaLxKJ2UzNi6S7J89Bw/og02leb+OdCZSJDYG9J6xr+8/Ndsga5xeiJr8Jht55199bKLviuLYjoO39GAiZzmu08WMA34P/grZyakkuMFlWXQNyABHpN6xnxQ3O6OqDd7F942MnTrM2xChbM/XXtPKLmRhPdbxqHHLYeLxv/xFA3MnOhI+G0izA/7JsT+0104wioZH+F8Ck9HzoJrLyjZLTLYzv4JydLWGtOjbLOD6jCd4cPlt4z28DqsulRqSrc5A3zMu3fhNjKBfWC3oH0rTrFcm1nc+U60Fois7/T9+3KSjH9YuR/7sLIxeQ74X8cr5d+9pkp34ffb5fVilAln426Tts6kzIEY8kuKT1nAGwuPKlTXvLpn4V9G2s9ugqSvJz5YYNL5r5es= alexb@Bancey-W11"
      ]
    }
    ipconfig {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway_ip_address
      }
    }
  }

  startup {
    order    = var.startup_order
    up_delay = var.startup_delay
  }

  agent {
    enabled = true
  }

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    bridge  = var.network_bridge_name
    vlan_id = var.vlan_tag
  }

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
  }
}
