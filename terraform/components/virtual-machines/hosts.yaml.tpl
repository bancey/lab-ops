all:
  children:
    %{ for cluster_key, cluster in k8s ~}
    ${ cluster_key }_k3s_cluster:
      hosts:
      %{ for vm_key, vm in cluster.vms ~}
      ${ vm_key }:
        ansible_host: $S{ vm }
      %{ endfor ~}
    %{ endfor ~}
