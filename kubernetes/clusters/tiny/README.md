# Dependency-Based Kustomization Structure

This directory contains a new dependency-based kustomization structure for the tiny cluster that provides better flexibility and prevents data loss during updates.

## Structure Overview

The kustomizations are organized in a hierarchical dependency chain:

```
Infrastructure Base (Cilium, CNI)
├── Core Controllers (cert-manager, traefik)
├── Core Configs (ingress routes, certificates)
├── Storage Controllers (Longhorn, NFS CSI)
├── Database Controllers (CloudNative-PG, MariaDB Operator, Dragonfly)
└── Application Groups
    ├── Networking Only Apps (no storage/database dependencies)
    ├── NFS Storage Apps (require NFS storage)
    └── Complex Storage Apps (require Longhorn + databases)
```

## Key Benefits

1. **Granular Dependencies**: Apps only wait for infrastructure they actually need
2. **Independent Updates**: Each group can be updated independently without affecting others
3. **Data Preservation**: Storage-dependent apps are grouped together, reducing data loss risk
4. **Logical Organization**: Apps are grouped by technical requirements, not arbitrary categories

## Application Groups

### Networking Only Apps
- **Dependencies**: Core controllers + configs only
- **Current Apps**: smokeping, discord, capacitor, twingate, external-services
- **Deployment Time**: Fastest (no storage/database dependencies)

### NFS Storage Apps  
- **Dependencies**: Core controllers + configs + NFS CSI
- **Current Apps**: None in tiny cluster (placeholder for future)
- **Use Case**: Apps requiring NFS persistent volumes

### Complex Storage Apps
- **Dependencies**: Core controllers + configs + Longhorn + PostgreSQL + MariaDB
- **Current Apps**: monica, bunkerweb-mgmt, pelican
- **Deployment Time**: Longest (waits for all storage and database infrastructure)

## Dependency Chain

1. `cluster-infrastructure-base` → Base infrastructure (Cilium)
2. `cluster-core-controllers` → Essential controllers (cert-manager, traefik)
3. `cluster-core-configs` → Basic ingress and certificate setup
4. `cluster-storage-longhorn` → Longhorn storage system
5. `cluster-storage-nfs` → NFS CSI driver and storage classes
6. `cluster-database-postgres` → CloudNative-PG operator
7. `cluster-database-mariadb` → MariaDB operator
8. `cluster-database-dragonfly` → Dragonfly Redis-compatible cache
9. Application groups deploy in parallel once their dependencies are ready

## Data Preservation

- **Storage-dependent apps** are grouped together in `apps-complex-storage`
- **Updates to networking-only apps** won't trigger recreation of storage apps
- **Database operators** are separate from storage, allowing independent updates
- **Flux health checks** ensure infrastructure is ready before apps deploy

## Migration from Old Structure

The old monolithic structure:
```
infrastructure → app-dependencies-controllers → app-dependencies-configs → apps
```

Has been replaced with the new dependency-based structure that allows:
- Apps with no storage dependencies to deploy immediately after basic infrastructure
- Apps with storage dependencies to wait only for their specific requirements
- Independent updates of different app categories

## Manual Data Preservation Steps

If you need to update storage infrastructure components:

1. **Before Update**: 
   ```bash
   # Backup any critical data from PVCs
   kubectl get pvc -A
   # Document current PVC bindings and storage classes
   ```

2. **During Update**:
   - Flux will update infrastructure components first
   - Apps will only restart if their dependencies change
   - PVCs should remain bound and data preserved

3. **After Update**:
   ```bash
   # Verify PVCs are still bound
   kubectl get pvc -A
   # Check app pods are running normally
   kubectl get pods -A
   ```

## Future Expansion

To add new apps:

1. **Identify dependencies**: Storage type, database requirements
2. **Choose appropriate group**: networking-only, nfs-storage, or complex-storage  
3. **Add to relevant kustomization**: Update the appropriate `apps-*/kustomization.yaml`
4. **Test in isolation**: The group structure allows testing new apps without affecting others