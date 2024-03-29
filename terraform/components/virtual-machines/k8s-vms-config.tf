resource "terraform_data" "hosts" {
  triggers_replace = [
    proxmox_virtual_environment_vm.wanda_k8s_virtual_machines[*],
    proxmox_virtual_environment_vm.hela_k8s_virtual_machines[*],
    proxmox_virtual_environment_vm.thor_k8s_virtual_machines[*],
    proxmox_virtual_environment_vm.loki_k8s_virtual_machines[*]
  ]

  provisioner "local-exec" {
    command = <<EOF
      
    EOF
  }
}