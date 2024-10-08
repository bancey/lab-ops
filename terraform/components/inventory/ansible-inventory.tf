resource "github_repository_file" "hosts" {
  repository = data.github_repository.this.name
  branch     = "main"
  file       = "ansible/hosts.yaml"
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = local.k8s_hosts
      vms = var.virtual_machines
      cts = var.containers
    }
  )
  commit_message      = "feat: update hosts file"
  overwrite_on_create = true
}
