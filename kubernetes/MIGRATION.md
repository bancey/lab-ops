# Migration Guide: Base Configs Refactor

This document describes the changes made during the Kubernetes configuration refactor to normalize base configs and isolate cluster-specific settings.

## Overview

The refactor separates cluster-agnostic base configurations from cluster-specific overlays, following Kustomize best practices. This improves maintainability, reusability, and clarity.

## What Changed

### Base Configurations (`kubernetes/apps/base/`)

Base configurations have been cleaned up to remove all cluster-specific values:

| Application | Changes |
|-------------|---------|
| **plex** | Removed ingress config, LoadBalancer IP, cluster-specific PVC names, moved ingress-route to overlay |
| **grafana** | Removed storageClassName, disabled ingress by default |
| **acquisitions** | Normalized PVC names (removed `-nfs-static` suffix) in radarr, sonarr, prowlarr, sabnzbd |
| **monica** | Removed hostname and storageClassName |
| **zigbee2mqtt** | Commented out serial port IP and frontend URL |
| **pelican** | Removed APP_URL hostname, removed mariadb storageClassName |
| **bunkerweb-mgmt** | Moved configmap, certificates, and ingress-route to tiny overlay, removed mariadb storageClassName |

### Cluster Overlays

#### Wanda Overlay (`kubernetes/apps/wanda/`)

**New patches added:**
- `plex-patch.yaml` - Ingress, LoadBalancer, and PVC configurations
- `acquisitions-patch.yaml` - Cluster-specific PVC names for radarr, sonarr, prowlarr, sabnzbd

**Moved resources:**
- `plex-ingress-route.yaml` - Moved from base

#### Tiny Overlay (`kubernetes/apps/tiny/`)

**New patches added:**
- `grafana-patch.yaml` - Enhanced with storageClassName
- `monica-patch.yaml` - Hostname and storageClassName
- `zigbee2mqtt-patch.yaml` - Serial port and frontend URL
- `pelican-patch.yaml` - APP_URL and mariadb storageClassName
- `bunkerweb-mgmt-mariadb-patch.yaml` - MariaDB storageClassName

**Moved resources:**
- `bunkerweb-mgmt-configmap.yaml` - Moved from base (entirely cluster-specific)
- `bunkerweb-mgmt-certificates.yaml` - Moved from base
- `bunkerweb-mgmt-ingress-route.yaml` - Moved from base

## Impact on Deployments

### For Existing Clusters

**No Breaking Changes**: The refactor maintains the same effective configuration through Kustomize patches. All cluster-specific values are now in overlays, producing identical output.

### Validation Results

All cluster overlays have been validated:
- ✅ YAML syntax validation passed (yamllint)
- ✅ Kustomize build successful for wanda overlay
- ✅ Kustomize build successful for tiny overlay
- ✅ Kustomize build successful for minikube overlay

## Benefits

1. **Improved Reusability**: Base configs can be used across any cluster
2. **Clear Separation**: Cluster-specific values are isolated in overlays
3. **Easier Maintenance**: Changes to base configs don't require updating multiple clusters
4. **Better Documentation**: Clear distinction between generic and cluster-specific configuration
5. **Kustomize Best Practices**: Follows recommended patterns for overlay management

## How to Apply Changes

### Automatic (Flux GitOps)

Changes will be automatically applied by Flux CD on the next reconciliation cycle (default: 10 minutes).

Monitor reconciliation:
```bash
flux get kustomizations -A
```

Force reconciliation:
```bash
flux reconcile kustomization cluster-apps -n flux-system
```

### Manual (kubectl kustomize)

If deploying manually:

```bash
# Build the manifests
kubectl kustomize kubernetes/apps/wanda/ > wanda-manifests.yaml

# Review the output
less wanda-manifests.yaml

# Apply (if needed)
kubectl apply -f wanda-manifests.yaml
```

## Verifying the Changes

### 1. Compare Kustomize Output (Before/After)

The refactor should produce identical effective configuration:

```bash
# Before refactor (git checkout to previous commit)
kubectl kustomize kubernetes/apps/wanda/ > before.yaml

# After refactor
kubectl kustomize kubernetes/apps/wanda/ > after.yaml

# Compare
diff before.yaml after.yaml
```

### 2. Check Running Applications

Verify applications are running correctly:

```bash
# Check HelmReleases
flux get helmreleases -A

# Check pods
kubectl get pods -A | grep -E "plex|grafana|radarr|sonarr"

# Check services
kubectl get svc -A | grep -E "plex|grafana"
```

### 3. Validate Ingress

Ensure ingress routes are correctly configured:

```bash
kubectl get ingressroute -A
```

## Troubleshooting

### Issue: Application Not Starting

**Cause**: PVC name mismatch after refactor

**Solution**: Check that cluster overlay patches use correct PVC names:
```bash
kubectl get pvc -n <namespace>
# Verify the patch references the correct PVC name
```

### Issue: Ingress Not Working

**Cause**: Ingress route not properly moved to overlay

**Solution**: Verify overlay kustomization includes the ingress-route resource:
```bash
kubectl kustomize kubernetes/apps/<cluster>/ | grep -A 10 "kind: IngressRoute"
```

### Issue: Storage Not Mounting

**Cause**: storageClassName not specified in overlay patch

**Solution**: Add storage class patch to the cluster overlay:
```yaml
spec:
  values:
    persistence:
      storageClassName: longhorn  # or appropriate class
```

## Future Additions

When adding new applications:

1. **Create cluster-agnostic base** in `kubernetes/apps/base/<app>/`
2. **Add cluster-specific values** in overlays (`wanda/`, `tiny/`, `minikube/`)
3. **Follow patterns** documented in `kubernetes/README.md`
4. **Validate** with `yamllint` and `kubectl kustomize`

## Rollback Plan

If issues arise, you can roll back to the previous commit:

```bash
# Identify the commit before refactor
git log --oneline

# Revert to previous state (example)
git revert <refactor-commit-sha>

# Or checkout previous commit temporarily
git checkout <previous-commit-sha> -- kubernetes/
```

Then push changes and let Flux reconcile.

## Questions?

For questions or issues related to this refactor:
1. Check the [Kubernetes README](./README.md) for usage patterns
2. Review Kustomize output with `kubectl kustomize`
3. Check Flux reconciliation status with `flux get kustomizations -A`
4. Open an issue in the repository

## Summary

This refactor establishes a clean, maintainable structure that follows Kubernetes and Kustomize best practices. Base configurations are now truly reusable across clusters, while cluster-specific settings are isolated in overlays where they belong.
