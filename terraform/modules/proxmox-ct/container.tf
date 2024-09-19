resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.target_node
  vm_id       = var.ct_id
  description = var.ct_description
  pool_id     = var.resource_pool
  started     = var.start_on_boot
  tags        = var.tags

  initialization {
    hostname = var.ct_name

    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.gateway_ip_address
      }
    }


    user_account {
      password = var.password
      keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDM6YQbnTJYYO6ANWiTwAU6LYLgwPkOu5sbDiUCYJt0dYgYUHzRa1cQsVE2ooLlmxwtHuL/8tjQtajL/HCaqr+XF41inGw3rz4cIXsQreRwudJNdP9Ba+2eaLxKJ2UzNi6S7J89Bw/og02leb+OdCZSJDYG9J6xr+8/Ndsga5xeiJr8Jht55199bKLviuLYjoO39GAiZzmu08WMA34P/grZyakkuMFlWXQNyABHpN6xnxQ3O6OqDd7F942MnTrM2xChbM/XXtPKLmRhPdbxqHHLYeLxv/xFA3MnOhI+G0izA/7JsT+0104wioZH+F8Ck9HzoJrLyjZLTLYzv4JydLWGtOjbLOD6jCd4cPlt4z28DqsulRqSrc5A3zMu3fhNjKBfWC3oH0rTrFcm1nc+U60Fois7/T9+3KSjH9YuR/7sLIxeQ74X8cr5d+9pkp34ffb5fVilAln426Tts6kzIEY8kuKT1nAGwuPKlTXvLpn4V9G2s9ugqSvJz5YYNL5r5es= alexb@Bancey-W11",
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4Vx68tO5cVPyWqC1l9eVrpFkLcQ7GV0tkdmR1Hx0k6wdtAGOFY4/20uI47wBFs0WAQwV1HR/hx8RSsCGVAuoqPqxYVPVAfyG38MyM70txdepKE2U2jRXq4tbwAfziOyllZFLSqP+uRWJ5rtffOV8rbDNOat8VBEIGIBsVlmtTHVwZfJvILyzI7pA4YLyweBFAJRBwVN/wP+Kylq4qs7khlwILTD/20/mLNWJGYqMRg58+rGWdJRhfLHgMV51oLpSDS7aHbhkVLjoVuLeqUARYfMdrPPf0lDWGlKAsRyIy1EO9Or7hk6BKTB5hA4G11vRmhoc9d9jcuoArOpUtKWQqoRU74GpSeGLmN2cUndUDrY4kEPzFORHBlKe5W1jt2rc7NRIhduOakrfRmzZGv3N2zoYin69XcRMaAwFXkCT9zIBSGYYvEoXLwX5DynmfHcCvl3/CPYRPX7oFQLMN0ghCWYCmibmTRLD0boB88hFGog/mun51L+aJyLvjBQHXaU6m5gTkJ3LUfkhZbbWPzhgyqLdw7MUfGF9LU5S8sEO71MxmiI76vLxfO/rpUoQpVG0oRde1TAwY7wgnWwFb7MmJ736+tLKzaFhshySrFodnRmcALzxkWYbNV+FI2Mz8ZdkTLvveJEmaiGdgf2B/RO2+VqX/QiCSJvFqcA6/eB35JQ== alexb@DESKTOP-CN2369K",
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8GRj4esk6kfB54F2h3M25PgcyOAl8mEey5BgHVkel05g+dBUGb/ERmoQ5itrMNhOy2mtrsguHDEW9tatwmKfmQQvZcbGKAt/BZjnQtTa/5iPdmq6C/B0URr7oTBBS9ClDfJOQNIxBKFcIujpkVtQHN84UhAw8UMwEMdKQtgiW1chUERSAuMQ+qzNtoFnZ1Do3C5gSiX0d1eZWr8UqCUab4cpjLnTQZO2KDIrrVJ1H9FGFida4vXEReDKxpzxp6IL+JjWwEzBF0TavPNRPRnbVdro+PT5Fk4Jz+GJtX4191xz1ePwbGKRYpyJQg58s9/nl5UobMvQNsx/cBAlX6ebemMcjD9YiCC1HK3rU9a5v8TDffqVpG50fbuL+c7aWWshMeIveat4WFTGPgnvAvT+ojQSSi2cVIL5qB/7s3uZkCOXTGeaTeKvCTF+d5U6DMjbTP5oOPGpcgWGzqvxT+0/fVDRQayTTsNGfxRGCDRwEIqBKSbo6HnMmQSt6zXtICUfVmldm+20kIwtaqej98tDRsB1/WUnaQaIjCeGHv8rZoqPla9t+8vk9bTHrJ6h9pxacNnECrtcSvA0Zs7u8Z3wkEVm25Uq6Kzdl8NqhWLIG8ct7Mmgs7p3Oj/5Qsrnt2+zUdVGOXwCKiDQnMsoeJ9/a3/p4pY+tnx6d9M5sbourxQ== alexb@Bancey-W11"
      ]
    }
  }

  network_interface {
    name    = "veth0"
    bridge  = var.network_bridge_name
    vlan_id = var.vlan_tag
  }

  operating_system {
    template_file_id = var.image_id
    type             = var.image_Type
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  cpu {
    architecture = var.cpu_architecture
    cores        = var.cpu_cores
  }

  memory {
    dedicated = var.memory
  }

  startup {
    order    = var.startup_order
    up_delay = var.startup_delay
  }

  unprivileged = true
  features {
    nesting = true
  }
}
