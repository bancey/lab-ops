resource "terraform_data" "k8s_hosts" {
  triggers_replace = [
    local.master_vms,
    local.worker_vms
  ]

  for_each = { for value in concat(local.master_vms, local.worker_vms) : "${value.target_node}-${value.vm_name}" => value if contains(var.target_nodes, lower(value.target_node)) }

  provisioner "local-exec" {
    command = <<EOF
      yq -i e 'all.children.wanda_k3s_cluster.hosts.${each.value.vm_name}.ansible_host = ${each.value.ip_address}' ${path.cwd}/../../../ansible/hosts.yaml
    EOF
  }
}
