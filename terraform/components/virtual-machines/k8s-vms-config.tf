resource "local_sensitive_file" "key_file" {
  content         = data.azurerm_key_vault_secret.key_file.value
  filename        = "${replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")}/id_rsa"
  file_permission = 0600
}

resource "terraform_data" "k8s_ansible" {
  triggers_replace = timestamp()
  for_each         = { for key, value in var.kubernetes_virtual_machines : key => value if var.target_nodes == value.target_nodes }

  depends_on = [local_sensitive_file.key_file]

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      key = each.key
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}