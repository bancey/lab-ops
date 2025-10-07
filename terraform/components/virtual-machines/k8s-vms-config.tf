resource "terraform_data" "k8s_ansible" {
  for_each = { for key, value in var.kubernetes_virtual_machines : key => value if var.target_nodes == value.target_nodes }

  depends_on = [
    module.wanda_k8s_virtual_machines,
    module.tiny_k8s_virtual_machines
  ]

  # Triggers replacement when:
  # - ansible_trigger changes
  # - VMs are recreated
  # - k3s.yaml changes
  triggers_replace = {
    ansible_trigger = each.value.ansible_trigger
    vm_modules      = jsonencode([module.wanda_k8s_virtual_machines, module.tiny_k8s_virtual_machines])
    k3s_playbook    = filemd5("../../../ansible/k3s.yaml")
  }

  # Reboot only when the resource is being replaced AND ansible_reboot_hosts is true
  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      playbook  = "k3s.yaml"
      arguments = "-e run_prep=true -e run_install=true -e passed_hosts=${each.key}_k3s_cluster -e reboot_hosts=${each.value.ansible_reboot_hosts} -e reboot_timeout=1200"
    })
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
