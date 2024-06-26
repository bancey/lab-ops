resource "terraform_data" "k8s_ansible" {
  for_each = { for key, value in var.kubernetes_virtual_machines : key => value if var.target_nodes == value.target_nodes }

  depends_on = [
    module.wanda_k8s_virtual_machines,
    module.hela_k8s_virtual_machines,
    module.thor_k8s_virtual_machines,
    module.loki_k8s_virtual_machines
  ]

  triggers_replace = [
    each.value.ansible_trigger,
    module.wanda_k8s_virtual_machines,
    module.hela_k8s_virtual_machines,
    module.thor_k8s_virtual_machines,
    module.loki_k8s_virtual_machines
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      key = each.key
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
