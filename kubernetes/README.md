# Kubernetes Configuration Structure

This directory contains all Kubernetes manifests managed via GitOps using Flux CD. The configuration follows Kustomize best practices with a clear separation between base configurations and cluster-specific overlays.

## Directory Structure

```
kubernetes/
├── apps/
│   ├── base/              # Cluster-agnostic base configurations
│   ├── wanda/             # Wanda cluster overlay
│   ├── tiny/              # Tiny cluster overlay
│   └── minikube/          # Minikube cluster overlay
├── app-dependencies/      # Infrastructure controllers and configs
├── bootstrap/             # Bootstrap secrets and keys
├── flux/                  # Flux GitOps configuration
│   ├── clusters/          # Cluster-specific Flux configs
│   └── repositories/      # Helm and Git repositories
└── infrastructure/        # Infrastructure services
```

## Configuration Philosophy

### Base Configurations (`apps/base/`)

Base configurations are **cluster-agnostic** and contain only the essential, reusable manifest definitions. They should:

- ✅ Work on any cluster without modification
- ✅ Use generic defaults (e.g., `ClusterIP` services)
- ✅ Omit cluster-specific settings (hostnames, IPs, storage classes)
- ✅ Use placeholder values or comments for required cluster-specific fields
- ✅ Disable ingress by default (enabled in overlays)

**Example: Base HelmRelease**
```yaml
# kubernetes/apps/base/example/release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: example
  namespace: example
spec:
  values:
    # Hostname should be configured in cluster overlays
    hostname: example.com
    service:
      type: ClusterIP  # Generic default
    ingress:
      enabled: false   # Enabled in overlays
    persistence:
      enabled: true
      size: 10Gi
      # storageClassName configured in overlays
```

### Cluster Overlays (`apps/wanda/`, `apps/tiny/`, `apps/minikube/`)

Cluster overlays contain **all cluster-specific configuration** using Kustomize patches. They should:

- ✅ Reference base configurations
- ✅ Patch cluster-specific values (hostnames, IPs, storage classes)
- ✅ Add cluster-specific resources (PVs, PVCs, certificates, ingress routes)
- ✅ Override resource limits if needed
- ✅ Enable/disable features per cluster

**Example: Cluster Overlay Structure**
```yaml
# kubernetes/apps/wanda/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base/example
  - example-pvc.yaml
  - example-certs.yaml
patchesStrategicMerge:
  - example-patch.yaml
```

**Example: Cluster Patch**
```yaml
# kubernetes/apps/wanda/example-patch.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: example
  namespace: example
spec:
  values:
    hostname: example.wanda.heimelska.co.uk
    service:
      type: LoadBalancer
      annotations:
        lbipam.cilium.io/ips: 10.152.15.100
    ingress:
      enabled: true
    persistence:
      storageClassName: nfs-csi
```

## Adding a New Application

### 1. Create Base Configuration

```bash
cd kubernetes/apps/base/
mkdir my-app
cd my-app
```

Create the base manifests:
- `namespace.yaml` - Namespace definition
- `release.yaml` - HelmRelease or Deployment (cluster-agnostic)
- `kustomization.yaml` - Kustomize configuration

### 2. Create Cluster Overlay

```bash
cd kubernetes/apps/wanda/  # or tiny/ or minikube/
```

Edit `kustomization.yaml` to add:
```yaml
resources:
  - ../base/my-app
  - my-app-pvc.yaml          # If needed
  - my-app-certs.yaml        # If needed
  - my-app-ingress.yaml      # If needed
patchesStrategicMerge:
  - my-app-patch.yaml
```

Create `my-app-patch.yaml` with cluster-specific settings.

### 3. Validate Configuration

```bash
# Validate YAML syntax
yamllint kubernetes/apps/

# Test Kustomize build
kubectl kustomize kubernetes/apps/wanda/
kubectl kustomize kubernetes/apps/tiny/
kubectl kustomize kubernetes/apps/minikube/
```

## Cluster-Specific Patterns

### Storage Classes

**Base (omit or comment):**
```yaml
persistence:
  enabled: true
  size: 10Gi
  # storageClassName: configured in overlay
```

**Overlay (patch):**
```yaml
spec:
  values:
    persistence:
      storageClassName: longhorn  # or nfs-csi, local-path, etc.
```

### Ingress Configuration

**Base (disabled):**
```yaml
ingress:
  enabled: false
```

**Overlay (enabled with cluster-specific host):**
```yaml
spec:
  values:
    ingress:
      enabled: true
      hosts:
        - app.cluster.domain.com
      tls:
        - secretName: app-tls
          hosts:
            - app.cluster.domain.com
```

### LoadBalancer Services

**Base (ClusterIP):**
```yaml
service:
  type: ClusterIP
```

**Overlay (LoadBalancer with IP):**
```yaml
spec:
  values:
    service:
      type: LoadBalancer
      annotations:
        lbipam.cilium.io/ips: 10.152.15.51
```

### PersistentVolume Claims

PVCs with cluster-specific storage backends should be defined in overlays:

```yaml
# kubernetes/apps/wanda/my-app-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data-pvc-nfs-static
  namespace: my-app
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  volumeName: my-app-data-pv-nfs
  storageClassName: nfs-csi
```

Then patch the HelmRelease to use this PVC name.

## Migration from Legacy Configuration

If you have an existing deployment with cluster-specific values in base:

1. **Identify cluster-specific values**: hostnames, IPs, storage classes, LoadBalancer annotations
2. **Create a patch file** in the appropriate cluster overlay
3. **Remove or comment out** cluster-specific values from base
4. **Test the Kustomize build** to ensure it produces the same output
5. **Validate with `yamllint`** before committing

## GitOps Workflow

1. **Make changes** to base or overlay configurations
2. **Validate** with `yamllint` and `kubectl kustomize`
3. **Commit and push** to the repository
4. **Flux automatically reconciles** changes to the cluster (default: 10 minutes)
5. **Monitor** with `flux get kustomizations -A`

## Troubleshooting

### Kustomize Build Fails

```bash
# Check for syntax errors
kubectl kustomize kubernetes/apps/wanda/ 2>&1 | less

# Common issues:
# - Missing patch target (ensure base resource exists)
# - Incorrect paths in kustomization.yaml
# - YAML indentation errors
```

### Application Not Updating

```bash
# Check Flux reconciliation status
flux get kustomizations -A

# Force reconciliation
flux reconcile kustomization cluster-apps -n flux-system
```

### Resource Conflicts

If you see conflicts between base and overlay:
- Ensure patches use correct strategic merge or JSON patch syntax
- Check that patch targets match base resource names/namespaces
- Use `kubectl kustomize` to preview the final output

## Best Practices

1. **Keep base configs minimal** - only essential, reusable configuration
2. **All cluster-specific values in overlays** - hostnames, IPs, storage, etc.
3. **Use comments for optional fields** in base configs
4. **Test Kustomize builds** before committing
5. **Validate YAML syntax** with yamllint
6. **Document cluster-specific requirements** in overlay READMEs
7. **Use consistent naming** - e.g., `app-name-patch.yaml`
8. **Leverage Kustomize patches** instead of duplicating entire resources

## References

- [Kustomize Documentation](https://kustomize.io/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
