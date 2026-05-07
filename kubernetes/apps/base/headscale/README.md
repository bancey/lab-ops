# Headscale Deployment

This directory contains the Kubernetes manifests for deploying Headscale, a self-hosted Tailscale control server, to the tiny cluster for lab VPN evaluation.

## Overview

Headscale is deployed via Flux GitOps using the gabe565 Helm chart. It provides VPN connectivity management for lab operations as an alternative to Twingate.

## Components

- **Namespace**: `headscale` - Isolated namespace for Headscale resources
- **HelmRelease**: Deploys Headscale server using the gabe565/headscale chart
- **Secret**: SOPS-encrypted secrets for OIDC and noise private key
- **ConfigMap**: ACL configuration for network access control

## Configuration

### Network Configuration

The deployment is configured with the following network settings inspired by the existing Twingate configuration:

- **VPN IP Range**: `100.64.0.0/10` (IPv4) and `fd7a:115c:a1e0::/48` (IPv6)
- **Lab Network**: `10.151.16.0/24` (matching tiny_k8s network from Twingate config)
- **DNS Domain**: `lab.local`
- **MagicDNS**: Enabled for automatic DNS resolution

### Access Control Lists (ACLs)

The ACL configuration defines three main groups based on Twingate structure:

1. **group:admins** - Full access to all resources
2. **group:lab-users** - Access to lab network and limited VPN services (SSH, HTTP, HTTPS)
3. **group:services** - Service accounts with access to lab network

### DERP Servers

Currently configured to use Headscale's built-in DERP servers with automatic updates enabled. Custom DERP servers can be configured later if needed.

## Deployment

Headscale is automatically deployed to the tiny cluster via Flux when changes are pushed to main. The deployment includes:

1. Headscale server with HTTP API (port 8080)
2. gRPC API (port 50443) for client authentication
3. Metrics endpoint (port 9090) for monitoring
4. Persistent storage (1Gi) for SQLite database

## Usage

### Creating Users

Once deployed, users can be created using the Headscale CLI:

```bash
# Exec into the headscale pod
kubectl exec -n headscale -it deployment/headscale -- headscale users create <username>

# Generate a pre-authentication key for a user
kubectl exec -n headscale -it deployment/headscale -- headscale preauthkeys create --user <username> --reusable --expiration 24h
```

### Connecting Clients

Clients can connect using the Tailscale client with the Headscale control server URL:

```bash
# On the client machine
tailscale up --login-server=http://headscale.headscale.svc.cluster.local:8080 --authkey=<preauthkey>
```

### Managing ACLs

ACLs are managed through the ConfigMap in `release.yaml`. To update ACLs:

1. Edit the `acl.json` configuration in `release.yaml`
2. Commit and push changes
3. Flux will automatically apply the updates

## Integration Points

### Comparison with Twingate

This deployment provides similar functionality to the existing Twingate setup:

- **Twingate Groups** → **Headscale ACL Groups**
  - `all`, `birds`, `plex`, `tiny_k8s`, `wanda_k8s` → `admins`, `lab-users`, `services`

- **Twingate Networks** → **Headscale Hosts**
  - `banceylab` network → `lab-network` (10.151.16.0/24)

- **Twingate Resources** → **Headscale ACL Rules**
  - Protocol-based access control (TCP/UDP ports)
  - Network-based access control (IP ranges)

### Future Enhancements

Potential improvements for production use:

1. **TLS/HTTPS**: Configure ingress with TLS certificates for secure external access
2. **OIDC Integration**: Configure OIDC provider for centralized authentication
3. **Custom DERP Servers**: Deploy and configure custom DERP servers for improved performance
4. **DNS Integration**: Integrate with existing AdGuard DNS servers
5. **Monitoring**: Add Prometheus metrics collection and Grafana dashboards
6. **High Availability**: Configure database replication for HA deployment

## Secrets

The following secrets need to be configured in `secret.sops.yaml`:

- `HEADSCALE_OIDC_CLIENT_SECRET`: OIDC client secret (if using OIDC authentication)
- `HEADSCALE_NOISE_PRIVATE_KEY`: Noise protocol private key (auto-generated on first run)

Secrets are encrypted using SOPS with Age encryption and the key stored in Azure Key Vault.

## Troubleshooting

### Check Headscale Logs

```bash
kubectl logs -n headscale deployment/headscale -f
```

### Verify Service Connectivity

```bash
kubectl run -n headscale test-curl --rm -it --image=curlimages/curl -- curl http://headscale:8080/health
```

### List Connected Nodes

```bash
kubectl exec -n headscale -it deployment/headscale -- headscale nodes list
```

## References

- [Headscale GitHub](https://github.com/juanfont/headscale)
- [Headscale Documentation](https://headscale.net/)
- [gabe565 Helm Chart](https://github.com/gabe565/charts/tree/main/charts/headscale)
- [Tailscale Client Documentation](https://tailscale.com/kb/1080/cli/)
