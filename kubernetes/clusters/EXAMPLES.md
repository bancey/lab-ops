# Examples: Adding New Applications

This document provides examples of how to add new applications to the dependency-based kustomization structure.

## Example 1: Adding a Simple Networking App

**Scenario**: Add a new monitoring dashboard that only needs ingress/certificates

**Steps**:
1. Create app manifests in `kubernetes/apps/base/new-dashboard/`
2. Add cluster-specific configurations in `kubernetes/apps/{cluster}/`
3. Add to the appropriate networking-only group:

```yaml
# kubernetes/clusters/tiny/apps-networking-only/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # ... existing resources ...
  - ../../apps/base/new-dashboard
  - ../../apps/tiny/new-dashboard-certificates.yaml
  - ../../apps/tiny/new-dashboard-ingress-route.yaml
```

**Result**: App deploys immediately after core infrastructure (~5 minutes)

## Example 2: Adding an App with Longhorn Storage

**Scenario**: Add a new database that requires persistent storage

**Steps**:
1. Create app manifests with PVC requiring `storageClass: longhorn`
2. Add to the complex storage group (since most Longhorn apps also need databases):

```yaml
# kubernetes/clusters/tiny/apps-complex-storage/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # ... existing resources ...
  - ../../apps/base/new-database
  - ../../apps/tiny/new-database-storage.yaml
```

**Result**: App waits for Longhorn + database operators (~15-20 minutes)

## Example 3: Adding an NFS Storage App

**Scenario**: Add a media processing app to wanda cluster that needs large file storage

**Steps**:
1. Create app manifests with NFS PVCs
2. Add PV/PVC manifests for NFS shares
3. Add to NFS storage group:

```yaml
# kubernetes/clusters/wanda/apps-nfs-storage/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # ... existing resources ...
  - ../../apps/wanda/media-processor-config-pv.yaml
  - ../../apps/wanda/media-processor-config-pvc.yaml
  - ../../apps/wanda/media-processor-data-pv.yaml
  - ../../apps/wanda/media-processor-data-pvc.yaml
  - ../../apps/base/media-processor
```

**Result**: App waits for NFS CSI driver (~8-10 minutes)

## Example 4: Moving an App Between Dependency Groups

**Scenario**: An app initially deployed as "networking only" now needs database storage

**Before** (networking only):
```yaml
# kubernetes/clusters/tiny/apps-networking-only/kustomization.yaml
resources:
  - ../../apps/base/simple-app
```

**After** (complex storage):
```yaml
# kubernetes/clusters/tiny/apps-networking-only/kustomization.yaml
# Remove simple-app from here

# kubernetes/clusters/tiny/apps-complex-storage/kustomization.yaml
resources:
  # ... existing resources ...
  - ../../apps/base/simple-app
  - ../../apps/tiny/simple-app-postgres.yaml  # New database config
```

**Migration**: 
1. App will be removed from networking group
2. Database infrastructure will be deployed if not already present
3. App will be recreated with new storage dependencies
4. **Data preservation**: Ensure any existing data is backed up first

## Example 5: Adding a New Cluster

**Scenario**: Add a new "staging" cluster with similar profile to "tiny"

**Steps**:
1. Copy tiny cluster structure:
   ```bash
   cp -r kubernetes/clusters/tiny kubernetes/clusters/staging
   ```

2. Customize infrastructure patches in `infrastructure.yaml` and storage configurations

3. Customize app groups based on what staging needs:
   ```yaml
   # Maybe staging doesn't need all the complex apps
   # kubernetes/clusters/staging/apps-complex-storage/kustomization.yaml
   resources:
     - ../../apps/base/monica  # Only monica for staging
     # Remove bunkerweb-mgmt and pelican
   ```

4. Create cluster-specific configuration files in `kubernetes/apps/staging/`

5. Update main cluster flux configuration to reference new structure

## Example 6: Handling Dependencies Between App Groups

**Scenario**: An app in "networking-only" needs to communicate with an app in "complex-storage"

**Solution**: The dependency structure doesn't prevent inter-app communication, it only controls deployment order.

```yaml
# The networking app can still reference services from storage apps
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  backend_url: "http://monica.monica.svc.cluster.local"
  # This works fine - networking apps can talk to storage apps
```

**Important**: The groups only affect when apps are deployed, not how they communicate at runtime.

## Best Practices

### 1. Choose the Right Group
- **Networking only**: No persistent storage, no databases
- **NFS storage**: Large files, media, shared storage
- **Complex storage**: Databases, stateful apps, persistent workloads

### 2. Consider Update Impact
- **Frequent updates**: Use networking-only group for faster deployment
- **Stable storage apps**: Use complex storage group, updates are less frequent but safer

### 3. Test in Lower Environments
- **Minikube**: Test basic functionality
- **Staging/Wanda**: Test with realistic dependencies
- **Tiny (production)**: Final deployment

### 4. Plan for Data Migration
- **Storage changes**: Always backup PVCs first
- **Database migrations**: Use database-specific backup/restore procedures
- **Cross-group moves**: Expect app recreation, plan for downtime

### 5. Monitor Dependencies
- **Flux reconciliation**: Watch kustomization status during deployments
- **Health checks**: Verify infrastructure dependencies before app deployment
- **Resource readiness**: Ensure storage and databases are actually ready, not just deployed

This structure provides flexibility while maintaining clear operational boundaries and data safety.