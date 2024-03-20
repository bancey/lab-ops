locals {
  password_hash = length(regexall("", var.password)) > 0 ? var.password : sha256(var.password)
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = templatefile("${path.module}/cloud-config.tftpl", {
      username = var.username
      password = local.password_hash
    })

    file_name = "cloud-config.yaml"
  }
}