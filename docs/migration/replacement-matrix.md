# Azure Service Replacement Matrix

> Part of the Azure Exit Plan for bancey/lab-ops

This document recommends replacements for each Azure service currently in use, with cost estimates, migration complexity, and risk assessments.

---

## Quick Summary

| Azure Service | Recommended Replacement | Complexity | Cost Impact |
|---|---|---|---|
| Azure Key Vault (secrets) | SOPS + Age (already in use) + GitHub Encrypted Secrets | Low | None (free) |
| Azure Blob Storage (Terraform state) | Cloudflare R2 or self-hosted MinIO on Proxmox | Low | Low |
| Azure Blob Storage (DB backups) | Cloudflare R2 or Backblaze B2 | Low | Low |
| Azure Virtual Machines (game server) | Hetzner Cloud VMs | Low–Medium | Lower |
| Azure VPN Gateway | Remove (replaced by Twingate, already in use) | Low | None |
| Azure Active Directory | Remove (Twingate handles access; OIDC for GitHub Actions) | Medium | None |
| Azure DevOps Pipelines | GitHub Actions | Medium | None (free tier) |
| Azure DevOps Self-Hosted Agents | GitHub Actions self-hosted runners (already on Kubernetes) | Low | None |

---

## 1. Azure Key Vault → SOPS + Age + GitHub Encrypted Secrets

### Current usage
All Terraform components read secrets from `bancey-vault` at plan/apply time. The pipeline fetches secrets using `AzureCLI@2` tasks.

### Primary recommendation: SOPS + Age (already in repo) + GitHub Encrypted Secrets

SOPS with Age encryption is **already in use** for Kubernetes secrets in this repo (`.sops.yaml`, `kubernetes/bootstrap/`). Extend this pattern to Terraform inputs.

**Approach:**
1. Store all secrets currently in Key Vault as GitHub Actions encrypted secrets (organisation or repository level).
2. For Terraform, pass secrets as environment variables (`TF_VAR_*`) from GitHub Actions secrets.
3. For Ansible, pass secrets via `--extra-vars` or Ansible Vault, sourced from GitHub Actions secrets.
4. For SOPS-encrypted files, the Age key itself becomes a single GitHub Actions secret (`SOPS_AGE_KEY`).

**Tooling available:** `sops`, `age`, `age-keygen` — all referenced in the repo's bootstrap docs.

### Alternative: 1Password Connect (self-hosted)

1Password Connect can be self-hosted on-premise and exposes a REST API compatible with the 1Password Terraform provider and Ansible lookup plugins. This provides a UI-friendly secret manager without cloud dependency.

- **Cost:** 1Password Teams (~$4/user/month) or self-hosted Connect (requires existing subscription).
- **Pros:** UI, audit log, per-item sharing.
- **Cons:** Requires on-prem server and a paid 1Password subscription.

### Alternative: HashiCorp Vault (self-hosted)

Deploy Vault on Proxmox as an LXC container. Integrates with Terraform via `vault` provider and with Ansible via `hashi_vault` lookup.

- **Cost:** Free (OSS).
- **Pros:** Mature, dynamic secrets, fine-grained policies.
- **Cons:** Operational overhead; HA requires multiple nodes.

### Cost estimate
- **SOPS + GitHub Secrets:** Free.
- **1Password Connect:** ~$4–8/month depending on seat count.
- **HashiCorp Vault:** Free software; ~£0–10/month in Proxmox compute if on dedicated LXC.

### Migration complexity: Low

Most secrets simply need to be added to GitHub Actions secrets. Terraform variables need `TF_VAR_` prefixes. The SOPS/Age infrastructure already exists for Kubernetes.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| GitHub secrets are not auditable beyond access logs | Use 1Password Connect or Vault if audit trail required |
| Secret rotation is manual | Add periodic rotation reminder; eventually automate with GitHub Actions scheduled workflow |
| Secrets visible to all repo contributors with Actions access | Use repository environments with protection rules to restrict access |

---

## 2. Azure Blob Storage (Terraform State) → Cloudflare R2

### Current usage
All six Terraform components use `backend "azurerm"` pointing to `banceystatestor` storage account.

### Primary recommendation: Cloudflare R2

Cloudflare R2 is S3-compatible, has no egress fees, and offers a generous free tier (10 GB storage, 1 million Class A operations/month). Terraform's `s3` backend supports R2 via custom endpoint.

**Backend config:**

```hcl
terraform {
  backend "s3" {
    bucket                      = "lab-ops-tfstate"
    key                         = "tfstate/component.tfstate"
    region                      = "auto"
    endpoint                    = "https://<account_id>.r2.cloudflarestorage.com"
    access_key                  = var.r2_access_key
    secret_key                  = var.r2_secret_key
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

### Alternative: Self-hosted MinIO on Proxmox

MinIO is an S3-compatible object store that can run as a lightweight LXC or VM on Proxmox.

- **Cost:** Free (MinIO Community Edition).
- **Pros:** Fully self-hosted, no internet dependency for state operations.
- **Cons:** Requires disk on Proxmox; HA needs replication setup; state data is on-prem (risk if Proxmox is unavailable).

### Alternative: Backblaze B2

B2 is S3-compatible and cheap ($0.006/GB/month, free up to 10 GB).

### Cost estimate
- **Cloudflare R2:** Likely free (state files are tiny).
- **MinIO:** Free software; uses existing Proxmox storage.
- **Backblaze B2:** Effectively free for state files.

### Migration complexity: Low

Terraform supports migrating state between backends with `terraform state push` / `terraform init -migrate-state`. No code changes beyond updating `init.tf` backend blocks.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| State lock not supported by R2 (no native DynamoDB equivalent) | Use Terraform Cloud free tier for state locking, or accept risk for small team |
| MinIO node failure makes state unavailable | Keep MinIO on HA storage or replicate to R2 as backup |

---

## 3. Azure Blob Storage (Database Backups) → Cloudflare R2 or Backblaze B2

### Current usage
`ansible/postgresql.yaml` and `ansible/mariadb.yaml` install `azcopy` and push backups to `banceyprodstor.blob.core.windows.net` using SAS tokens.

### Primary recommendation: Cloudflare R2 + rclone

Replace `azcopy` with `rclone`, which is S3-compatible and supports R2, B2, and many other backends.

**Ansible change:** Replace `azcopy copy` command with `rclone sync` or `rclone copy` targeting R2 bucket.

```bash
rclone copy "${LOCAL_DIR}/" r2:lab-ops-backups/postgresql/ \
  --s3-provider Cloudflare \
  --s3-endpoint "https://<account_id>.r2.cloudflarestorage.com" \
  --s3-access-key-id "${R2_ACCESS_KEY}" \
  --s3-secret-access-key "${R2_SECRET_KEY}"
```

### Alternative: Backblaze B2 + rclone

Backblaze B2 has a native `rclone` configuration profile and a large free tier (10 GB). Same `rclone` tooling works.

### Alternative: Self-hosted MinIO on Proxmox

Store backups on local MinIO. Simple and fast for restores; no egress cost.

- **Risk:** If Proxmox storage fails, backups may be lost alongside data. Off-site replication recommended.

### Cost estimate
- **R2:** Free up to 10 GB; ~$0.015/GB/month beyond.
- **B2:** Free up to 10 GB; $0.006/GB/month beyond.
- **MinIO:** Free; uses existing Proxmox storage.

### Migration complexity: Low

Drop-in replacement: swap `azcopy` for `rclone`, update credentials. No schema or data changes.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| rclone not installed by default | Add `install rclone` task in Ansible (like current `install azcopy` task) |
| Backup continuity during transition | Run both azcopy and rclone in parallel during first backup cycle; verify checksums |

---

## 4. Azure Virtual Machines (Game Server) → Hetzner Cloud

### Current usage
Game server nodes run Pelican/Pterodactyl on Azure VMs (`Standard_F2ams_v6`) in `uksouth` with public IPs, VNet, NSG, and Twingate for VPN access.

### Primary recommendation: Hetzner Cloud

Hetzner provides affordable, high-performance VMs with a straightforward API and Terraform provider. The `CCX23` (4 vCPU, 16 GB RAM, 160 GB NVMe) or `CX32` (4 vCPU, 8 GB RAM) are cost-effective equivalents.

**Terraform provider:** `hetznercloud/hcloud` (mature, well-documented).

**Network equivalent:** Hetzner Cloud Networks (private networking) + Firewall rules (equivalent to NSG).

**Twingate:** Continue using Twingate — deploy Twingate connector on Hetzner VM as before.

**Estimated Hetzner costs:**
- `CX32` (4 vCPU, 8 GB): ~€7.5/month
- `CCX23` (4 vCPU, 16 GB): ~€25/month
- IPv4: ~€0.5/month per IP
- Outbound traffic: first 20 TB free

**Azure equivalent cost:**
- `Standard_F2ams_v6` (2 vCPU, 4 GB): ~$140/month (pay-as-you-go, uksouth)

**Savings: significant** — Hetzner is typically 5–10× cheaper.

### Alternative: Hetzner Dedicated / Bare Metal

For game servers with consistent load, bare metal provides better performance per pound.

### Alternative: Fly.io

Fly.io supports Docker-based deployments with persistent volumes and global anycast. Pterodactyl/Pelican may require workarounds for Docker-in-Docker.

- **Cost:** ~$5–20/month depending on size.
- **Limitation:** No custom kernel; may not support all game server requirements.

### Alternative: Self-hosted on Proxmox (on-prem)

If on-prem capacity allows, move game server VMs to Proxmox like the rest of the infrastructure. No cloud cost.

- **Limitation:** Requires public IP/port forwarding or Twingate relay; hardware availability.

### Cost estimate
- **Hetzner Cloud:** Low (~€10–25/month per server).
- **Fly.io:** Low-Medium (~$10–30/month).
- **Proxmox on-prem:** No additional cloud cost; uses existing hardware.

### Migration complexity: Medium

Requires:
1. New Terraform module (`hcloud` provider instead of `azurerm`).
2. Reprovisioning VMs and reinstalling Pelican/Pterodactyl (via existing Ansible/Terraform provisioner).
3. DNS cutover (Cloudflare already manages this).
4. Twingate connector reinstallation on new VMs.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Game servers require persistent storage | Use Hetzner Volumes (block storage, ~€0.052/GB/month) |
| Public IP changes affect DNS | Use Cloudflare DNS proxy; update A records as part of migration |
| Twingate setup on new platform | Use existing `setup-twingate.sh` provisioner script; adapt for Hetzner |
| Azure-specific VM extension for Twingate setup | Convert to `cloud-init` or `remote-exec` provisioner |

---

## 5. Azure VPN Gateway → Remove (Twingate already provides this)

### Current usage
`terraform/components/cloud-vpn-gateway/` deploys an Azure VPN Gateway for hybrid connectivity. Based on the current `init.tf`, the actual VPN resources are minimal.

### Analysis
Twingate is **already in use** throughout this infrastructure for secure access to on-premise resources. The Twingate connectors on Raspberry Pis provide zero-trust network access without requiring a cloud VPN gateway.

### Recommendation: Decommission Azure VPN Gateway

Remove the `cloud-vpn-gateway` Terraform component entirely. Twingate already provides equivalent or superior connectivity with lower cost and complexity.

If site-to-site VPN is genuinely needed for specific non-Twingate traffic:
- **WireGuard** (self-hosted, free) — can run on any Proxmox VM or Raspberry Pi.
- **Tailscale** (free tier) — alternative to Twingate for zero-trust access.

### Cost estimate
- **Remove VPN Gateway:** Saves Azure VPN Gateway cost (~$27–$138/month depending on SKU).
- **WireGuard:** Free.
- **Tailscale:** Free for personal/small teams.

### Migration complexity: Low

Verify Twingate covers all current VPN use cases, then run `terraform destroy` on the `cloud-vpn-gateway` component.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Some traffic may depend on VPN Gateway for routing | Audit network routes before decommissioning |
| Twingate outage affects all remote access | Maintain WireGuard as backup access path |

---

## 6. Azure Active Directory / Entra ID → Remove (OIDC for GitHub Actions)

### Current usage
- Game server VMs use system-assigned managed identity for Key Vault access.
- AAD login enabled on game server VMs (`enable_aad_login = true`).
- Azure AD group manages KV reader role.
- Service principal (`MSDN New`) used for all Azure operations from the pipeline.

### Recommendation: Remove with Azure services

When Azure VMs and Key Vault are replaced, AAD/Entra ID dependencies are automatically eliminated.

For GitHub Actions authentication to non-Azure providers:
- Use **OIDC federation** with Hetzner/Cloudflare as needed (Hetzner has a Terraform provider with API key auth; no OIDC required).
- Use **GitHub Actions encrypted secrets** for API tokens.

For VM SSH access on Hetzner:
- Use **SSH key pairs** managed via Terraform (already the pattern for on-prem VMs).
- No cloud identity provider required.

### Cost estimate: None (cost elimination)

### Migration complexity: Low (happens automatically with VM/KV migration)

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Loss of centralised identity audit log | Implement SSH key rotation policy; log access via Twingate activity logs |

---

## 7. Azure DevOps Pipelines → GitHub Actions

### Current usage
`infra-pipeline.yaml` is a full Azure DevOps YAML pipeline orchestrating Terraform, Ansible, and Kubernetes operations. Self-hosted agents run on Kubernetes (tiny cluster) and on-premise VMs.

### Primary recommendation: GitHub Actions

GitHub Actions is **already in use** (`.github/workflows/lint.yaml`). Migrating the full infra pipeline to GitHub Actions eliminates Azure DevOps entirely.

**Key equivalences:**

| Azure DevOps | GitHub Actions |
|---|---|
| `AzureCLI@2` task | Remove (secrets come from GH Encrypted Secrets) |
| `azuredevops-lib` templates | Composite actions or reusable workflows in this repo |
| Stage-level environments | GitHub Environments with protection rules |
| `vmImage: ubuntu-latest` | `runs-on: ubuntu-latest` |
| Service connection | OIDC or API token in GitHub Secrets |
| Self-hosted agent pool | Self-hosted GitHub Actions runners |

**Self-hosted runners:** The existing Kubernetes deployment (`kubernetes/apps/base/azdevops/`) can be adapted to run `actions-runner-controller` (ARC) instead of the Azure DevOps agent. ARC is the standard Kubernetes-native GitHub Actions runner.

**Twingate integration:** The `twingate-connect` step from `azuredevops-lib` can be replicated in GitHub Actions using the Twingate GitHub Action (`twingate/github-action-setup-twingate`).

### Alternative: Retain Azure DevOps (not recommended)

Retaining Azure DevOps would require an active Azure subscription. Not aligned with the exit goal.

### Alternative: Woodpecker CI (self-hosted)

Woodpecker CI is a lightweight, self-hosted CI/CD system compatible with GitHub webhooks. Runs on Kubernetes.

- **Pros:** Fully self-hosted; no GitHub dependency.
- **Cons:** Less ecosystem tooling; additional operational burden.

### Cost estimate
- **GitHub Actions:** Free for public repos; 2,000 minutes/month free for private repos; self-hosted runners are free.
- **Woodpecker CI:** Free; uses existing cluster compute.

### Migration complexity: Medium

Requires rewriting `infra-pipeline.yaml` as GitHub Actions workflows. Logic is complex (stage dependencies, conditional deployment, Twingate integration) but all patterns have GitHub Actions equivalents.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| GitHub Actions YAML syntax differs from ADO | Migrate incrementally, test each stage |
| `azuredevops-lib` templates have no GH equivalent | Re-implement as composite actions; simpler than ADO templates |
| Self-hosted runner security (docker socket mount) | Use `dind` sidecar or rootless Docker; restrict runner permissions |
| GitHub Actions minutes limit for private repo | Use self-hosted runners for compute-heavy jobs |

---

## 8. Azure DevOps Self-Hosted Agents → GitHub Actions Self-Hosted Runners

### Current usage
- Kubernetes deployment in `tiny` cluster: 2 replicas of `bancey/ado-agent:latest`
- On-premise VM deployment via `ansible/ado-agent.yaml`

### Recommendation: actions-runner-controller (ARC)

Replace the Azure DevOps agent deployment with ARC, which provides Kubernetes-native GitHub Actions runner management.

**ARC provides:**
- Auto-scaling runners on Kubernetes
- Ephemeral runner pods (better security)
- Helm chart deployment (fits existing GitOps pattern)

**Helm chart:** `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller`

### Cost estimate: None (uses existing cluster)

### Migration complexity: Low

Swap the ADO agent deployment for ARC. No infrastructure changes required.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Docker socket requirement for builds | Use `dind` sidecar or kaniko for container builds |
| Runner registration requires GitHub token | Use GitHub App for runner registration (more secure than PAT) |

---

## Cost Comparison Summary

| Service | Current (Azure) | Replacement | Estimated Saving |
|---|---|---|---|
| Key Vault | ~$5/month | GitHub Secrets (free) | ~$5/month |
| Blob Storage (state) | ~$2/month | Cloudflare R2 (free tier) | ~$2/month |
| Blob Storage (backups) | ~$5–20/month | R2 / B2 (free–low) | ~$5–20/month |
| Azure VMs (game server) | ~$140/month/VM | Hetzner (~€10–25/month) | ~$115–130/month/VM |
| VPN Gateway | ~$27–138/month | Twingate (already paid) / WireGuard (free) | ~$27–138/month |
| Azure DevOps | Free (MSDN credits) | GitHub Actions (free) | $0 (both free) |
| **Total (estimated)** | **~$180–300/month** | **~€15–30/month** | **~$150–270/month** |

> Note: Actual Azure costs depend on usage patterns, reserved instances, and MSDN credit consumption. Hetzner prices are in EUR and may vary.
