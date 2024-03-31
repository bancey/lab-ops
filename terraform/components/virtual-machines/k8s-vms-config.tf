resource "local_sensitive_file" "key_file" {
  content         = data.azurerm_key_vault_secret.key_file.value
  filename        = "${replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")}/id_rsa"
  file_permission = 0600
}

resource "terraform_data" "k8s_ansible" {
  for_each = { for key, value in var.kubernetes_virtual_machines : key => value if var.target_nodes == value.target_nodes }

  provisioner "local-exec" {
    command     = <<-EOT
      eval `ssh-agent -s`
      ssh-add id_rsa
      ansible-galaxy install -r requirements.yml
      ansible-playbook --inventory hosts.yaml k3s.yaml --extra-vars run_prep=true run_install=true passed_hosts=${each.key}_k3s_cluster
    EOT
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}