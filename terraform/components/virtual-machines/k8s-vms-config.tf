resource "terraform_data" "k8s_hosts" {
  triggers_replace = [
    local.master_vms,
    local.worker_vms
  ]

  for_each = { for value in concat(local.master_vms, local.worker_vms) : "${value.target_node}-${value.vm_name}" => value if contains(var.target_nodes, lower(value.target_node)) }

  provisioner "local-exec" {
    command     = <<-EOT
      yq -i '.all.children.wanda_k3s_cluster.hosts.${each.value.vm_name}.ansible_host = "${each.value.ip_address}"' vm-${each.value.vm_id}.yaml
    EOT
    interpreter = ["/bin/bash", "-c"]
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
  }
}


resource "terraform_data" "combine_hosts" {
  triggers_replace = terraform_data.k8s_hosts

  depends_on = [terraform_data.k8s_hosts]

  provisioner "local-exec" {
    command     = <<-EOT
      files=$(find . -name "vm-*.yaml" |xargs echo)
      echo "Found files: $files"
      if [[ -n "$files" ]]; then
        yq eval-all '. as $item ireduce ({}; . *+ $item)' $files > hosts.yaml
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
  }
}
