resource "terraform_data" "hosts_replace" {
  triggers_replace = timestamp()
}

resource "local_file" "hosts" {
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = local.k8s_hosts
    }
  )
  filename = "../../../ansible/k8s-vms.yaml"

  lifecycle {
    replace_triggered_by = [terraform_data.hosts_replace]
  }
}

resource "terraform_data" "combine_hosts" {
  triggers_replace = timestamp()

  depends_on = [local_file.hosts]

  provisioner "local-exec" {
    command     = "yq eval-all '. as $item ireduce ({}; . *+ $item)' hosts.yaml k8s-vms.yaml > hosts.yaml"
    interpreter = ["/bin/bash", "-c"]
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
  }
}
