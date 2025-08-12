# Migration Guide: Dependency-Based Kustomizations

This guide provides steps for migrating from the old monolithic kustomization structure to the new dependency-based structure.

## Overview of Changes

### Old Structure Problems
- **Monolithic dependencies**: All apps waited for all infrastructure (Longhorn, NFS, databases) even if unused
- **Data loss risk**: Single apps kustomization meant any change could recreate all apps
- **Inflexible grouping**: Apps grouped by arbitrary categories rather than technical dependencies
- **Slow deployments**: Simple networking apps waited for complex storage infrastructure

### New Structure Benefits
- **Granular dependencies**: Apps only wait for infrastructure they actually use
- **Independent updates**: Different app groups can update without affecting others
- **Data preservation**: Storage apps grouped separately from networking apps
- **Faster deployments**: Simple apps deploy immediately after basic infrastructure

## Migration Steps

### Phase 1: Preparation (Safe)
1. **Backup critical data** from any persistent volumes:
   ```bash
   kubectl get pvc -A
   # Document current PVC states and applications using them
   ```

2. **Review current deployments**:
   ```bash
   kubectl get kustomization -n flux-system
   kubectl get helmrelease -A
   ```

### Phase 2: Deploy New Structure (No Downtime)
The new structure is designed to be deployed alongside the old one initially:

1. **Apply new flux cluster configuration** (points to new dependency structure):
   ```bash
   # This creates the new kustomizations but doesn't remove old ones yet
   kubectl apply -f kubernetes/clusters/tiny/flux-cluster.yaml
   ```

2. **Verify new kustomizations are created**:
   ```bash
   kubectl get kustomization -n flux-system
   # Should see both old and new kustomizations
   ```

3. **Wait for new kustomizations to become ready**:
   ```bash
   kubectl wait --for=condition=Ready kustomization/cluster-infrastructure-base -n flux-system --timeout=300s
   kubectl wait --for=condition=Ready kustomization/cluster-core-controllers -n flux-system --timeout=300s
   kubectl wait --for=condition=Ready kustomization/cluster-storage-longhorn -n flux-system --timeout=300s
   kubectl wait --for=condition=Ready kustomization/cluster-apps-complex-storage -n flux-system --timeout=300s
   kubectl wait --for=condition=Ready kustomization/cluster-apps-networking-only -n flux-system --timeout=300s
   ```

### Phase 3: Cutover (Minimal Disruption)
1. **Update flux-system to point to new structure**:
   ```bash
   # Update the main cluster kustomization to use the new path
   kubectl patch kustomization cluster-tiny -n flux-system --type merge -p '{"spec":{"path":"./kubernetes/clusters/tiny"}}'
   ```

2. **Remove old kustomizations** (Flux will clean these up automatically):
   ```bash
   # The old kustomizations will be pruned by Flux since they're no longer referenced
   # Monitor this process:
   kubectl get kustomization -n flux-system -w
   ```

### Phase 4: Validation
1. **Verify all applications are running**:
   ```bash
   kubectl get pods -A
   kubectl get helmrelease -A
   ```

2. **Check PVC states are preserved**:
   ```bash
   kubectl get pvc -A
   # Verify no PVCs were recreated (check AGE column)
   ```

3. **Test application functionality**:
   - Access each application to ensure they're working
   - Verify database connections are maintained
   - Check storage mounts are intact

## Rollback Plan

If issues occur, rollback is straightforward:

1. **Revert flux cluster configuration**:
   ```bash
   kubectl patch kustomization cluster-tiny -n flux-system --type merge -p '{"spec":{"path":"./kubernetes/flux/clusters/tiny"}}'
   ```

2. **Wait for old structure to reconcile**:
   ```bash
   flux reconcile kustomization cluster-tiny
   ```

## Expected Behavior During Migration

### What Should NOT Change
- **Pod recreations**: Existing pods should not be recreated unless configuration actually changes
- **PVC bindings**: Persistent volumes should remain bound to existing claims
- **Service endpoints**: Application endpoints should remain accessible
- **Database data**: All database data should be preserved

### What WILL Change
- **Kustomization resources**: Old kustomizations will be removed, new ones created
- **Deployment order**: Future deployments will follow new dependency chain
- **Update isolation**: Different app groups can now update independently

### Warning Signs (Require Immediate Rollback)
- **Pod recreations without config changes**: Indicates configuration conflict
- **PVC recreations**: Indicates potential data loss
- **Application downtime**: Indicates dependency issues
- **Database connection errors**: Indicates database operator issues

## Post-Migration Benefits

### Faster App Deployment
- **Networking apps** (smokeping, discord, capacitor, twingate): Deploy ~5-10 minutes faster
- **Complex apps** (monica, bunkerweb-mgmt, pelican): Same deployment time but more reliable

### Independent Updates
- **Update cert-manager**: Only affects core infrastructure, apps remain unaffected
- **Update Longhorn**: Only affects storage apps, networking apps unaffected  
- **Update applications**: Different groups can update without cross-impact

### Better Troubleshooting
- **Infrastructure issues**: Easier to identify if problem is in storage, databases, or networking
- **App issues**: Clearer dependency chain makes troubleshooting more focused
- **Flux reconciliation**: More granular status reporting per dependency group

## Maintenance

### Adding New Apps
1. **Identify dependencies**: What storage, databases, or special infrastructure does it need?
2. **Choose appropriate group**:
   - `apps-networking-only`: No special infrastructure dependencies
   - `apps-nfs-storage`: Requires NFS persistent volumes
   - `apps-complex-storage`: Requires Longhorn storage and/or databases
3. **Add to group kustomization**: Update the appropriate `kustomization.yaml`
4. **Test independently**: The group structure allows isolated testing

### Infrastructure Updates
- **Core infrastructure**: All dependent groups will wait for completion
- **Storage systems**: Only storage-dependent apps will wait
- **Database operators**: Only database-dependent apps will wait
- **Networking**: All apps depend on core networking, updates affect all groups

This new structure provides the flexibility requested in the issue while maintaining data safety and reducing deployment times.