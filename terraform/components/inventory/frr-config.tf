resource "github_repository_file" "frr_config" {
  repository = data.github_repository.this.name
  branch     = "main"
  file       = "ansible/frr.conf"
  content = templatefile("${path.module}/frr.conf.tpl",
    {
      k8s = local.k8s_hosts
    }
  )
  commit_message      = "feat: update BGP frr.conf"
  overwrite_on_create = true
}
