# Azure Service Replacement Matrix

> Part of the Azure Exit Plan for bancey/lab-ops

This document recommends replacements for each Azure service currently in use, with cost estimates, migration complexity, and risk assessments.

---

## Quick Summary

| Azure Service | Recommended Replacement | Complexity | Cost Impact |
|---|---|---|---|
| Azure Key Vault (secrets) | SOPS + Age (already in use) + GitHub Encrypted Secrets | Low | None (free) |
| Azure Blob Storage (Terraform state) | Azure Blob Storage (new sub) **or** Cloudflare R2 — see §2 | Low | Negligible |
| Azure Blob Storage (DB backups) | Cloudflare R2 or Backblaze B2 | Low | Low |
| Azure Virtual Machines (game server) | **Already decommissioned** — no action required | — | — |
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

## 2. Azure Blob Storage (Terraform State) → Decision Required

### Current usage
All six Terraform components use `backend "azurerm"` pointing to `banceystatestor` storage account.

### The locking question

**State locking is important.** Without it, two concurrent `terraform apply` runs can corrupt state. The `backend "azurerm"` achieves locking natively via Azure Blob Storage leases — no extra infrastructure required.

### Option A: Azure Blob Storage on a new Azure subscription (Recommended if locking is required)

Azure Blob Storage with `backend "azurerm"` provides **native, lease-based state locking** with no additional setup. Using a dedicated (non-MSDN-credit) Azure subscription keeps costs minimal and independent of expiring credits.

**Cost breakdown for Terraform state only:**

| Item | Price | Estimated monthly cost |
|---|---|---|
| LRS blob storage (state files are <1 MB each, ~9 files) | $0.018/GB/month | < $0.01 |
| Write operations (plan/apply ~100×/month) | $0.0525/10,000 ops | < $0.01 |
| Read operations | $0.004/10,000 ops | < $0.01 |
| **Total** | | **< $1/month** |

A Pay-As-You-Go Azure subscription has no standing monthly fee; you pay only for what you use. For state storage alone this is effectively free.

**Backend config (unchanged):**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "labopstfstate"
    container_name       = "tfstate"
    key                  = "component.tfstate"
  }
}
```

**Pros:**
- Native locking — no extra infrastructure or workarounds.
- Dead-simple migration: change storage account name, re-run `terraform init -migrate-state`.
- Well-tested, mature backend.

**Cons:**
- Retains a minimal Azure dependency (storage account only, no credits required).

---

### Option B: Cloudflare R2 (if minimising Azure footprint is the priority)

Cloudflare R2 is S3-compatible with no egress fees and a generous free tier. Terraform's `s3` backend supports R2 via a custom endpoint.

**⚠️ Locking limitation:** R2 does not implement the DynamoDB API. The `s3` backend's `dynamodb_table` parameter requires an actual DynamoDB-compatible endpoint. Running without `dynamodb_table` means **no state locking**.

For a single-operator repo with infrequent concurrent applies this risk is low, but it is a real risk for CI pipelines that might trigger parallel runs.

**Mitigations if choosing R2:**

1. **Terraform Cloud free tier** — Store state (and locking) in HCP Terraform (free up to 500 managed resources, unlimited workspaces). Use the `cloud` backend or `remote` backend. Introduces a new vendor dependency (HashiCorp) but is fully free.
2. **Accept no locking** — For a small solo/two-person team with serialised CI runs, this is low risk. Add `terraform force-unlock` to pipeline runbooks for the rare stuck-lock scenario.
3. **Self-hosted MinIO** — MinIO exposes a DynamoDB-compatible API for locking when combined with `terraform-backend-s3` and a compatible DynamoDB emulator. Complex to set up.

**Backend config with R2 (no locking):**

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

---

### Option C: Terraform Cloud / HCP Terraform (if locking + zero cloud storage cost is required)

HCP Terraform free tier provides state storage and locking without any storage account. The `cloud` backend is natively supported since Terraform 1.1.

- **Cost:** Free (up to 500 managed resources per workspace).
- **Pros:** Locking included, run history, remote execution optional.
- **Cons:** Introduces HCP/HashiCorp vendor dependency; requires Terraform Cloud account.

---

### Comparison summary

| Option | Native locking | Monthly cost | Azure dependency | Notes |
|---|---|---|---|---|
| **Azure Blob (new sub)** | ✅ Yes (native) | < $1 | Minimal (storage only) | Simplest path; recommended if locking is required |
| **Cloudflare R2** | ❌ No (DynamoDB required) | Free | None | Acceptable for solo use; risky with parallel CI |
| **Cloudflare R2 + HCP Terraform** | ✅ Yes (via HCP) | Free | None | Adds HCP dependency; most vendor-neutral option |
| **Self-hosted MinIO** | ⚠️ Complex | Free | None | High operational overhead |

### Recommendation

If state locking is a requirement: use **Azure Blob Storage on a new Pay-As-You-Go subscription** (Option A). The cost is negligible (< $1/month) and locking works out of the box with no code changes beyond swapping the storage account name.

If eliminating all Azure footprint is the priority: use **Cloudflare R2 + HCP Terraform free tier** (Option C variant), accepting the HCP dependency in exchange for native locking.

### Migration complexity: Low

Terraform supports migrating state between backends with `terraform state pull` / `terraform init -migrate-state`. No code changes beyond updating `init.tf` backend blocks.

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

## 4. Azure Virtual Machines (Game Server) — Already Decommissioned

The game servers have been decommissioned. No migration action is required for this service.

**Remaining clean-up tasks:**
- Confirm `terraform/components/game-server/` component is removed or its state is already destroyed.
- Verify resource groups `games-prod-rg` and `games-test-rg` are deleted in the Azure portal.
- Remove `game-server` state file entries from `banceystatestor` (will be handled in Phase 6 storage account deletion).
- Remove `Game-Server-Ports`, `Cloudflare-Main-API-Token`, and `Cloudflare-Main-Zone-*` Key Vault secrets that were used exclusively by the game server component (check `azure-inventory.md` for cross-usage before deleting).

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
- Game server VMs used system-assigned managed identity for Key Vault access — **already eliminated** with game server decommission.
- Azure AD group managed KV reader role — **no longer in use**.
- Service principal (`MSDN New`) used for all Azure operations from the pipeline.

### Recommendation: Remove with Azure services

The managed identity and AAD group dependencies were automatically eliminated when the game servers were decommissioned. The remaining AAD dependency is the `MSDN New` service principal used by Azure DevOps, which is eliminated in Stream 5 (CI/CD migration).

For GitHub Actions authentication to non-Azure providers:
- Use **OIDC federation** with Cloudflare/Hetzner as needed (these providers use API key auth; no OIDC required).
- Use **GitHub Actions encrypted secrets** for API tokens.

For VM SSH access on new infrastructure:
- Use **SSH key pairs** managed via Terraform (already the pattern for on-prem VMs).
- No cloud identity provider required.

### Cost estimate: None (cost elimination)

### Migration complexity: Low (partially already done by game server decommission)

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
| Blob Storage (state) | ~$2/month | Azure Blob new sub / R2 — see §2 | ~$1–2/month |
| Blob Storage (backups) | ~$5–20/month | R2 / B2 (free–low) | ~$5–20/month |
| Azure VMs (game server) | **Already decommissioned** | — | Already saved |
| VPN Gateway | ~$27–138/month | Twingate (already paid) / WireGuard (free) | ~$27–138/month |
| Azure DevOps | Free (MSDN credits) | GitHub Actions (free) | $0 (both free) |
| **Total (estimated)** | **~$40–165/month** (post game-server) | **~$0–1/month** | **~$38–164/month** |

> Note: Actual Azure costs depend on usage patterns and MSDN credit consumption. Game server savings are already realised.
