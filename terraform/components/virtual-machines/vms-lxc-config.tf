resource "terraform_data" "ansible" {
  for_each = { for key, value in var.ansible : key => value if var.target_nodes == value.nodes }

  depends_on = [
    module.tiny_containers,
    module.wanda_containers,
    module.wanda_virtual_machines,
    module.tiny_virtual_machines
  ]

  triggers_replace = [
    each.value.ansible.trigger,
    file("../../../ansible/${each.value.ansible.playbook}")
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      playbook  = each.value.ansible.playbook
      arguments = each.value.ansible.arguments
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
