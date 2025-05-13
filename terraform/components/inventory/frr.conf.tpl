router bgp 64600
 bgp router-id 10.151.10.1
 bgp ebgp-requires-policy
 maximum-paths 4
 redistribute connected
 redistribute static

%{ for cluster_key, cluster in k8s ~}
 neighbor cilium-${ cluster_key} peer-group
 neighbor cilium-${ cluster_key} remote-as ${ cluster.bgp_as }
 neighbor cilium-${ cluster_key} activate
 neighbor cilium-${ cluster_key} soft-reconfiguration inbound
 neighbor cilium-${ cluster_key} timers 15 45
 neighbor cilium-${ cluster_key} timers connect 15
 neighbor 10.151.15.8 peer-group cilium-${ cluster_key}
 neighbor 10.151.15.16 peer-group cilium-${ cluster_key}
 neighbor 10.151.15.17 peer-group cilium-${ cluster_key}
 neighbor 10.151.15.18 peer-group cilium-${ cluster_key}
 neighbor 10.151.15.19 peer-group cilium-${ cluster_key}
%{ for master in cluster.masters ~}
 neighbor ${ master } peer-group cilium-${ cluster_key}
%{ endfor ~}
%{ for worker in cluster.workers ~}
 neighbor ${ worker } peer-group cilium-${ cluster_key}
%{ endfor ~}
%{ endfor ~}

 address-family ipv4
%{ for cluster_key, cluster in k8s ~}
  neighbor cilium-${ cluster_key } activate
  neighbor cilium-${ cluster_key } send-community all
  neighbor cilium-${ cluster_key } route-map ALLOW-ALL in
  neighbor cilium-${ cluster_key } route-map ALLOW-ALL out
%{ endfor ~}
 exit-address-family

route-map ALLOW-ALL permit 10
