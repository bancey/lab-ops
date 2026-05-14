data "azurerm_key_vault_secret" "ansible_secrets" {
  for_each     = { for secret in local.ansible_secrets : "${secret.key}" => secret }
  name         = each.value.secret_name
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "terraform_data" "ansible" {
  for_each = { for key, value in var.ansible : key => value if var.target_nodes == value.nodes }

  depends_on = [
    module.tiny_containers,
    module.wanda_containers,
    module.wanda_virtual_machines,
    module.tiny_virtual_machines
  ]

  triggers_replace = [
    each.value.trigger,
    file("../../../ansible/${each.value.playbook}")
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      playbook    = each.value.playbook
      arguments   = each.value.arguments
      secret_keys = keys(each.value.secrets)
    })
    environment = { for arg_name, secret_name in each.value.secrets : "ANSIBLE_VAR_${upper(arg_name)}" => data.azurerm_key_vault_secret.ansible_secrets["${each.key}_${arg_name}"].value }
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
