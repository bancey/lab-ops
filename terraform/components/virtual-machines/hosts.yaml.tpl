all:
  children:
  %{ for cluster_key, cluster in k8s ~}
    ${ cluster_key }_k3s_cluster:
      hosts:
      %{ for master_key, master in cluster.masters ~}
        ${ master_key }:
          ansible_host: ${ master }
      %{ endfor ~}
      %{ for worker_key, worker in cluster.workers ~}
        ${ worker_key }:
          ansible_host: ${ worker }
      %{ endfor ~}
  %{ endfor ~}
