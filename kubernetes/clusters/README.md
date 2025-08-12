# Cluster-Specific Dependency-Based Kustomizations

This directory contains the new dependency-based kustomization structures for all clusters in the lab environment. Each cluster is organized by technical dependencies rather than arbitrary groupings.

## Directory Structure

```
kubernetes/clusters/
├── tiny/          # Production tiny cluster (Longhorn + databases + networking apps)
├── wanda/         # Media server cluster (NFS storage + networking apps)
└── minikube/      # Development cluster (networking apps only)
```

## Universal Dependency Chain

All clusters follow the same logical dependency hierarchy:

```
1. Infrastructure Base (Cilium, CNI)
2. Core Controllers (cert-manager, traefik)
3. Core Configs (ingress routes, certificates)
4. Storage Systems (Longhorn, NFS) [parallel deployment]
5. Database Systems (PostgreSQL, MariaDB, Dragonfly) [parallel deployment]
6. Application Groups [parallel deployment based on dependencies]
   ├── Networking Only Apps
   ├── NFS Storage Apps  
   └── Complex Storage Apps
```

## Cluster-Specific Configurations

### Tiny Cluster (`/tiny/`)
**Purpose**: Production environment with full infrastructure stack

**Infrastructure**:
- Cilium BGP with ASN 64602
- Longhorn for block storage
- NFS CSI for legacy storage (currently unused)
- CloudNative-PG for PostgreSQL
- MariaDB Operator
- Dragonfly Redis cache

**Application Groups**:
- **Networking Only**: smokeping, discord, capacitor, twingate, external-services
- **NFS Storage**: Empty (placeholder)
- **Complex Storage**: monica (Longhorn+PostgreSQL), bunkerweb-mgmt (Longhorn+MariaDB), pelican (Longhorn+MariaDB)

**Deployment Characteristics**:
- Full dependency chain: ~15-25 minutes total
- Networking apps: ~5-8 minutes
- Storage apps: ~15-25 minutes (waits for all dependencies)

### Wanda Cluster (`/wanda/`)
**Purpose**: Media server environment with heavy NFS usage

**Infrastructure**:
- Standard Cilium networking
- Longhorn available but not heavily used
- NFS CSI for media storage
- Database operators available but unused

**Application Groups**:
- **Networking Only**: capacitor
- **NFS Storage**: plex, acquisitions suite (radarr, sonarr, sabnzbd, prowlarr, qbittorrent)
- **Complex Storage**: Empty (placeholder)

**Deployment Characteristics**:
- NFS dependency chain: ~8-12 minutes total
- Networking apps: ~3-5 minutes
- NFS storage apps: ~8-12 minutes

### Minikube Cluster (`/minikube/`)
**Purpose**: Development and testing environment

**Infrastructure**:
- Minimal Cilium setup
- Storage and database operators disabled (placeholders only)

**Application Groups**:
- **Networking Only**: podinfo
- **Storage Groups**: All empty (placeholders)

**Deployment Characteristics**:
- Minimal dependency chain: ~3-5 minutes total
- All apps: ~3-5 minutes (no storage/database dependencies)

## Benefits of This Structure

### 1. Granular Dependencies
- Apps only wait for infrastructure they actually use
- No unnecessary delays for simple networking apps
- Storage-heavy clusters (wanda) optimize for NFS dependencies
- Database-heavy clusters (tiny) optimize for storage+database chains

### 2. Independent Updates
- **Infrastructure updates**: Only affect dependent app groups
- **Storage updates**: Don't affect networking-only apps
- **App updates**: Each group can update without affecting others
- **Cluster-specific optimization**: Each cluster optimized for its workload

### 3. Data Preservation
- Storage apps grouped together reduce recreation risk
- Database dependencies explicit and controlled
- PVC preservation through controlled update sequences

### 4. Scalability
- Easy to add new clusters with appropriate dependency profiles
- Infrastructure components can be mixed and matched per cluster
- App groups can be customized per cluster requirements

## Adding New Clusters

To add a new cluster, copy the structure from the most similar existing cluster:

1. **For networking-only clusters**: Copy from `minikube/`
2. **For NFS-heavy clusters**: Copy from `wanda/`
3. **For complex storage clusters**: Copy from `tiny/`

Then customize the infrastructure and app groups as needed.

## Migration Strategy

Each cluster can be migrated independently:

1. **Development first**: Start with `minikube` (lowest risk)
2. **Media services**: Migrate `wanda` (isolated workload)
3. **Production last**: Migrate `tiny` (highest stakes)

See individual cluster `MIGRATION.md` files for cluster-specific procedures.

## Maintenance

### Infrastructure Updates
- **Core networking**: Affects all clusters
- **Storage systems**: Only affects clusters using that storage type
- **Database operators**: Only affects clusters using databases

### Application Updates
- **Per-cluster**: Each cluster's apps update independently
- **Per-group**: Different app groups in same cluster update independently
- **Cross-cluster**: No cross-impact between clusters

### Troubleshooting
- **Dependency issues**: Check specific cluster's dependency chain
- **Storage problems**: Isolated to clusters using that storage type
- **App failures**: Isolated to specific app group within cluster

This structure provides the flexibility requested while maintaining operational simplicity and data safety across all environments.