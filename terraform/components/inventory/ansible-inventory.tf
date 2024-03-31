resource "local_file" "hosts" {
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = local.k8s_hosts
      vms = var.virtual_machines
    }
  )
  filename = "../../../ansible/hosts.yaml"
}
