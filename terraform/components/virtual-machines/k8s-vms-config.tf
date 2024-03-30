resource "local_file" "hosts" {
  content = templatefile("${path.module}/hosts.yaml.tpl",
    {
      k8s = { for cluster_key, cluster in local.k8s_hosts : cluster_key => cluster if contains(var.target_nodes, lower(cluster.target_nodes)) }
    }
  )
  filename = "../../../ansible/k8s-vms.yaml"
}

resource "terraform_data" "combine_hosts" {
  triggers_replace = timestamp()

  depends_on = [local_file.hosts]

  provisioner "local-exec" {
    command     = "yq eval-all '. as $item ireduce ({}; . *+ $item)' k8s-vms.yaml > hosts.yaml"
    interpreter = ["/bin/bash", "-c"]
    working_dir = replace(path.cwd, "/terraform/components/virtual-machines", "/ansible")
  }
}
