# This file is updated by Terraform to reflect the VMs deployed any updates should be made to the hosts.yaml.tpl file.
all:
  vars:
    ansible_user: bancey
  hosts:
%{ for vm_key, vm in vms ~}
    ${ vm_key }:
      ansible_host: ${ vm.ip_address }
${ endfor ~}
%{ for ct_key, ct in cts ~}
    ${ ct_key }:
      ansible_host: ${ ct.ip_address }
%{ endfor ~}
  children:
    rpi:
      hosts:
        thanos:
          ansible_host: 10.151.14.5
        gamora:
          ansible_host: 10.151.14.6
%{ for cluster_key, cluster in k8s ~}
    ${ cluster_key }:
      vars:
        metallb_ip_range: "${ cluster.metallb_ip_range }"
        k3s_etcd_datastore: ${ cluster.k3s_etcd_datastore }
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
