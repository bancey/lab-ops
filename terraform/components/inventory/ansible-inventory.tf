resource "terraform_data" "hosts_replace" {
  triggers_replace = timestamp()
}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = local.k8s_hosts
      vms = var.virtual_machines
    }
  )
  filename = "../../../ansible/hosts.yaml"

  lifecycle {
    replace_triggered_by = [terraform_data.hosts_replace]
  }
}
