resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/cloud-config.tftpl", {
      name     = var.vm_name
      password = data.local_sensitive_file.password_hash.content
      domain   = var.domain
      username = var.username
    })

    file_name = "${var.vm_name}-cloud-config.yaml"
  }
}

data "local_sensitive_file" "password_hash" {
  filename = "${path.module}/password_hash.txt"

  depends_on = [terraform_data.mkpassword]
}

resource "terraform_data" "mkpassword" {
  triggers_replace = [
    var.password
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sudo apt install whois
      mkpasswd -m sha-512 ${var.password} >> ${path.module}/password_hash.txt
    EOT
  }
}
