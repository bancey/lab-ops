resource "local_sensitive_file" "key_file" {
  content         = data.azurerm_key_vault_secret.key_file.value
  filename        = "${replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")}/id_rsa"
  file_permission = 0600
}

resource "terraform_data" "k8s_ansible" {
  for_each = { for key, value in var.kubernetes_virtual_machines : key => value if var.target_nodes == value.target_nodes }

  depends_on = [
    local_sensitive_file.key_file,
    module.wanda_k8s_virtual_machines,
    module.hela_k8s_virtual_machines,
    module.thor_k8s_virtual_machines,
    module.loki_k8s_virtual_machines
  ]

  lifecycle {
    replace_triggered_by = [
      module.wanda_k8s_virtual_machines.proxmox_virtual_environment_vm.vm,
      module.hela_k8s_virtual_machines.proxmox_virtual_environment_vm.vm,
      module.thor_k8s_virtual_machines.proxmox_virtual_environment_vm.vm,
      module.loki_k8s_virtual_machines.proxmox_virtual_environment_vm.vm
    ]
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      key = each.key
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}