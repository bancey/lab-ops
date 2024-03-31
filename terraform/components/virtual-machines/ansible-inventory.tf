resource "terraform_data" "hosts_replace" {
  triggers_replace = timestamp()
}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = local.k8s_hosts
      vms = { for vm_key, vm in var.virtual_machines : vm_key => vm if contains(var.target_nodes, lower(value.node))}
    }
  )
  filename = "../../../ansible/hosts.yaml"

  lifecycle {
    replace_triggered_by = [terraform_data.hosts_replace]
  }
}
