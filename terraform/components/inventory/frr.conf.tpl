router bgp 64600
 bgp router-id 10.151.10.1
 bgp ebgp-requires-policy
 maximum-paths 4
 redistribute connected
 redistribute static

%{ for cluster in k8s ~}
 neighbor cilium-${ cluster.name } peer-group
 neighbor cilium-${ cluster.name } remote-as ${ cluster.bgp_as }
 neighbor cilium-${ cluster.name } activate
 neighbor cilium-${ cluster.name } soft-reconfiguration inbound
 neighbor cilium-${ cluster.name } timers 15 45
 neighbor cilium-${ cluster.name } timers connect 15
%{ for master in cluster.masters ~}
 neighbor ${ master } peer-group cilium-${ cluster.name }
%{ endfor ~}
%{ for worker in cluster.workers ~}
 neighbor ${ worker } peer-group cilium-${ cluster.name }
%{ endfor ~}

%{ endfor ~}

 address-family ipv4
%{ for cluster in k8s ~}
  neighbor cilium-${ cluster.name } activate
  neighbor cilium-${ cluster.name } send-community all
  neighbor cilium-${ cluster.name } route-map ALLOW-ALL in
  neighbor cilium-${ cluster.name } route-map ALLOW-ALL out
%{ endfor ~}
 exit-address-family

route-map ALLOW-ALL permit 10
