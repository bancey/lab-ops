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
      playbook  = each.value.playbook
      arguments = each.value.arguments
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
