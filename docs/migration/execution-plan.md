# Azure Exit Plan: Execution Plan

> Part of the Azure Exit Plan for bancey/lab-ops  
> Issue: #1377

This document provides a phased, executable migration plan. Each phase has explicit tasks, dependencies, and acceptance criteria.

---

## Phase 0 — Safety Baseline

**Goal:** Ensure nothing is lost during migration. All current state is captured and backed up.

### Tasks

- [ ] **Export all Azure Key Vault secrets** — document current secret names and values (store in local encrypted file, not in repo).
- [ ] **Capture Terraform state** — run `terraform show -json` for each component and save outputs locally.
- [ ] **Export current Terraform state files** — `terraform state pull > backup-{component}.tfstate` for all state files (excluding `game-server` which is already destroyed).
- [ ] **Test PostgreSQL backup restore** — trigger a manual backup and restore it to a test PostgreSQL instance.
- [ ] **Test MariaDB backup restore** — trigger a manual backup and restore to test instance.
- [ ] **Document Azure DevOps pipeline service connections** — record all service connection details.
- [ ] **Screenshot/export Azure DevOps pipeline run history** — optional audit trail.
- [ ] **Define rollback criteria** — document conditions under which each phase should be rolled back.

### Acceptance criteria

- [ ] All Azure Key Vault secrets exported and securely stored locally.
- [ ] Terraform state backed up for all active components (game-server already gone).
- [ ] PostgreSQL backup restore dry-run successful.
- [ ] MariaDB backup restore dry-run successful.
- [ ] Rollback runbook written and reviewed.

### Rollback runbook (Phase 0)

Phase 0 is read-only — no changes to production. No rollback needed.

---

## Phase 1 — Secrets Migration (Azure Key Vault → GitHub Encrypted Secrets)

**Goal:** Move all secrets from Azure Key Vault to GitHub Encrypted Secrets. Update Terraform and Ansible to source secrets from environment variables instead of Key Vault.

**Prerequisite:** Phase 0 complete.

### Tasks

#### 1.1 Add secrets to GitHub

- [ ] Create GitHub repository environment `prod` with required reviewers.
- [ ] Create GitHub repository environment `test`.
- [ ] Add all Key Vault secrets as GitHub encrypted secrets (repository or environment level).
  - Naming convention: Keep same names, replacing `-` with `_` for env var compatibility.
  - Critical secrets: `CLOUDFLARE_LAB_API_TOKEN`, `CLOUDFLARE_MAIN_API_TOKEN`, `WANDA_PROXMOX_URL`, `WANDA_PROXMOX_USERNAME`, `WANDA_PROXMOX_PASSWORD`, `TINY_PROXMOX_URL`, `TINY_PROXMOX_USERNAME`, `TINY_PROXMOX_PASSWORD`, `HELA_PROXMOX_URL`, `LOKI_PROXMOX_URL`, `THOR_PROXMOX_URL`, `LAB_VM_USERNAME`, `LAB_VM_PASSWORD`, etc.
  - Add `SOPS_AGE_KEY` (Age private key) as a repository secret.
- [ ] Add Hetzner API token as `HCLOUD_TOKEN` (for future use in Phase 4).
- [ ] Add Cloudflare R2 credentials: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`.

#### 1.2 Update Terraform to use environment variables

For each Terraform component, replace `data "azurerm_key_vault_secret"` blocks with `variable` blocks and `TF_VAR_*` injection:

- [ ] Update `terraform/components/dns/interpolated-defaults.tf` — remove KV data sources; add variables for Cloudflare tokens, AdGuard credentials.
- [ ] Update `terraform/components/twingate/interpolated-defaults.tf` — remove KV data sources; add variables for Twingate URL and API token.
- [ ] Update `terraform/components/twingate/connector.tf` — replace `azurerm_key_vault_secret` writes with `local_file` or omit if tokens are consumed elsewhere.
- [ ] Update `terraform/components/virtual-machines/interpolated-defaults.tf` — remove KV data sources; add variables for Proxmox credentials, VM credentials, Cloudflare tokens.
- [ ] Update `terraform/components/virtual-machines/vms-lxc-config.tf` — remove KV data source for Ansible secrets; pass secrets via `TF_VAR_ansible_secrets` map variable.
- [ ] Update `terraform/components/inventory/interpolated-defaults.tf` — remove KV data sources; add variables for GitHub App credentials.
- [ ] Remove `azurerm` provider from any component that no longer needs it after removing KV references.
- [ ] Update `provider "cloudflare"` blocks to use `var.cloudflare_api_token` instead of KV secret.
- [ ] Update `provider "proxmox"` blocks to use variables instead of KV secrets.

#### 1.3 Update Ansible pipeline integration

- [ ] For each Ansible deployment in `infra-pipeline.yaml`, replace `AzureCLI@2` secret-fetch steps with direct environment variable injection from GitHub Actions secrets.
- [ ] Update `prod.tfvars` Ansible arguments block — replace `PostgreSQL-*-Password` Azure KV secret name references with new secret names/approach.
- [ ] Test Ansible playbooks locally with manually-set environment variables.

### Acceptance criteria

- [ ] `terraform plan` succeeds for all components without Azure Key Vault access.
- [ ] Ansible playbooks run successfully with secrets sourced from environment variables.
- [ ] No hardcoded secret values in any committed file.
- [ ] `yamllint .` passes.

### Rollback (Phase 1)

If secrets migration fails: revert Terraform variable changes and restore `data "azurerm_key_vault_secret"` blocks. GitHub encrypted secrets can remain without causing harm. Azure Key Vault is **not** decommissioned in this phase.

---

## Phase 2 — Terraform State Migration (Azure Blob → Cloudflare R2)

**Goal:** Move all Terraform remote state from `banceystatestor` Azure Blob Storage to Cloudflare R2.

**Prerequisite:** Phase 1 complete (no more Azure provider needed after KV removal in most components).

### Tasks

- [ ] Create Cloudflare R2 bucket `lab-ops-tfstate`.
- [ ] Generate R2 API token with read/write access to the bucket.
- [ ] Add R2 credentials to GitHub Actions secrets (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`).
- [ ] For each of the 9 Terraform components, run state migration:
  ```bash
  terraform init  # (with Azure backend, last time)
  terraform state pull > /tmp/backup-{component}.tfstate
  # Update init.tf to use S3/R2 backend
  terraform init -migrate-state
  terraform plan  # Verify: no changes expected
  ```
- [ ] Components to migrate (in order):
  - [ ] `inventory`
  - [ ] `twingate`
  - [ ] `dns`
  - [ ] `cloud-vpn-gateway` (test)
  - [ ] `cloud-vpn-gateway` (prod)
  - ~~`game-server` (test)~~ — already decommissioned, state already destroyed
  - ~~`game-server` (prod)~~ — already decommissioned, state already destroyed
  - [ ] `virtual-machines` (wanda)
  - [ ] `virtual-machines` (tiny)
- [ ] Update `infra-pipeline.yaml` / GitHub Actions workflow to pass R2 backend config instead of `backendStorageAccount`.
- [ ] Verify all state files present in R2 bucket.

### Acceptance criteria

- [ ] `terraform plan` produces no unexpected changes for all components.
- [ ] State files visible in R2 bucket.
- [ ] `banceystatestor` no longer referenced in any active workflow.

### Rollback (Phase 2)

Re-run `terraform init -migrate-state` with the original Azure backend config, using the backup state files from Phase 0. Azure storage account remains active until Phase 6.

---

## Phase 3 — Database Backup Migration (azcopy → rclone + R2)

**Goal:** Replace Azure Blob Storage database backups with Cloudflare R2 using rclone.

**Prerequisite:** Phase 0 (backups verified), Phase 2 (R2 credentials available).

### Tasks

- [ ] Create Cloudflare R2 bucket `lab-ops-backups`.
- [ ] Add R2 backup credentials to GitHub Actions secrets (can reuse Phase 2 credentials or create separate token).
- [ ] Update `ansible/postgresql.yaml`:
  - [ ] Replace `Install azcopy` task with `Install rclone` (download from `downloads.rclone.org`).
  - [ ] Replace backup upload command:
    ```bash
    # Old:
    azcopy copy "${LOCAL_DIR}/" "https://${STORAGE_ACCOUNT}.blob.core.windows.net/..."
    # New:
    rclone copy "${LOCAL_DIR}/" :s3:lab-ops-backups/postgresql/ \
      --s3-provider Cloudflare \
      --s3-endpoint "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
      --s3-access-key-id "${R2_ACCESS_KEY_ID}" \
      --s3-secret-access-key "${R2_SECRET_KEY}"
    ```
  - [ ] Remove `backup_sas_token` variable references; add `r2_access_key_id`, `r2_secret_key`, `r2_account_id`.
  - [ ] Update `backup_storage_account_name` variable to `r2_bucket_name`.
- [ ] Apply same changes to `ansible/mariadb.yaml`.
- [ ] Update `prod.tfvars` Ansible secrets block for `postgresql` — replace `backup_sas_token` with R2 secret references.
- [ ] Trigger manual backup cycle and verify files in R2 bucket.
- [ ] Perform restore test from R2 backup.

### Acceptance criteria

- [ ] PostgreSQL backup job completes and files appear in R2 bucket.
- [ ] MariaDB backup job completes and files appear in R2 bucket.
- [ ] Restore from R2 backup succeeds on test instance.
- [ ] `banceyprodstor` no longer receiving new backups.

### Rollback (Phase 3)

Revert Ansible playbook changes. Azure Blob backups continue uninterrupted (old backups remain in `banceyprodstor` until decommission in Phase 6).

---

## Phase 4 — Game Server ~~(Azure VMs → Hetzner Cloud)~~ — Already Decommissioned

The game servers have been decommissioned. Phase 4 is complete by default.

### Remaining clean-up tasks (incorporate into Phase 6)

- [ ] Confirm `terraform/components/game-server/` Terraform state has been destroyed (run `terraform state list` against the old state if accessible, or verify resource group is gone in Azure portal).
- [ ] Verify `games-prod-rg` and `games-test-rg` resource groups no longer exist in Azure.
- [ ] Remove the `game-server` (test + prod) state entries from Phase 2 migration list (no need to migrate state that is already destroyed).

### Acceptance criteria

- [ ] Azure resource groups `games-prod-rg` and `games-test-rg` confirmed deleted.

---

## Phase 5 — CI/CD Migration (Azure DevOps → GitHub Actions)

**Goal:** Replace `infra-pipeline.yaml` (Azure DevOps) with GitHub Actions workflows. Replace ADO self-hosted agents with GitHub Actions Runner Controller (ARC).

**Prerequisite:** Phases 1–4 complete (no more Azure resources to deploy against).

### Tasks

#### 5.1 GitHub Actions self-hosted runners (ARC)

- [ ] Add `actions-runner-controller` Helm chart to `kubernetes/app-dependencies/controllers/`.
- [ ] Create ARC `RunnerDeployment` or `RunnerSet` manifest in `kubernetes/apps/tiny/`.
- [ ] Configure GitHub App for runner registration (more secure than PAT).
- [ ] Deploy ARC via Flux GitOps.
- [ ] Verify runners appear in GitHub repository settings → Actions → Runners.
- [ ] Remove `kubernetes/apps/base/azdevops/` deployment.
- [ ] Remove `kubernetes/apps/tiny/azdevops-secret.sops.yaml`.
- [ ] Update `ansible/ado-agent.yaml` — remove or repurpose for ARC if on-prem runners needed.

#### 5.2 Terraform workflow

- [ ] Create `.github/workflows/terraform.yaml`:
  - Trigger: push to `main`, PR to `main` (excluding `ansible/hosts.yaml`, `kubernetes/**`).
  - Jobs: one per Terraform component, with dependencies matching current ADO stage deps.
  - Add Twingate connect step using Twingate GitHub Action (for components needing on-prem access).
  - Source secrets from GitHub Encrypted Secrets (`${{ secrets.* }}`).
  - Use R2 backend credentials for `terraform init`.
- [ ] Test workflow on a branch with `plan` only (no apply).
- [ ] Test workflow on `main` with `apply`.

#### 5.3 Ansible workflow

- [ ] Create `.github/workflows/ansible.yaml`:
  - Trigger: push to `main` (Ansible playbook files only).
  - Jobs: one per Ansible playbook deployment.
  - Add Twingate connect step.
  - Source secrets from GitHub Encrypted Secrets.
  - Use self-hosted ARC runner for SSH-based Ansible jobs.
- [ ] Test each Ansible job.

#### 5.4 Clean up Azure DevOps

- [ ] Disable `infra-pipeline.yaml` trigger (or rename to `infra-pipeline.yaml.bak`).
- [ ] Remove Azure DevOps service connection `MSDN New` from ADO project.
- [ ] Remove Azure DevOps pipeline from ADO project.
- [ ] Archive or delete the `bancey/azuredevops-lib` dependency reference.

### Acceptance criteria

- [ ] End-to-end deployment from GitHub Actions works without Azure.
- [ ] All Terraform components deploy successfully via GitHub Actions.
- [ ] All Ansible playbooks run successfully via GitHub Actions.
- [ ] Self-hosted runners visible in GitHub and functional.
- [ ] `infra-pipeline.yaml` is retired (renamed or deleted).

### Rollback (Phase 5)

Azure DevOps pipeline remains intact until GitHub Actions pipeline is fully validated. Can re-enable ADO pipeline at any time. ARC runners are additive and do not remove ADO agents until explicitly deleted.

---

## Phase 6 — Cutover and Azure Decommission

**Goal:** Final validation, Azure resource cleanup, and post-migration review.

**Prerequisite:** All Phases 0–5 complete and validated.

### Tasks

#### 6.1 Final validation

- [ ] Run full end-to-end deployment via GitHub Actions.
- [ ] Verify all applications operational across both Kubernetes clusters.
- [ ] Verify database backups running to R2.
- [ ] Verify game server operational on Hetzner.
- [ ] 7-day soak period — monitor for issues.

#### 6.2 Azure resource cleanup (safe order)

- [ ] Delete Azure DevOps self-hosted agent resources (if any remain).
- [x] Run `terraform destroy` on `game-server` — **already decommissioned**.
- [ ] Verify `games-prod-rg` and `games-test-rg` resource groups are gone (should already be deleted).
- [ ] Run `terraform destroy` on `cloud-vpn-gateway` (prod and test).
- [ ] Verify all Azure resource groups are empty.
- [ ] Delete `banceystatestor` storage account (Terraform state — old files).
- [ ] Delete `banceyprodstor` storage account (database backups — old files).
- [ ] Delete `bancey-vault` Key Vault (soft-delete will hold for 90 days by default).
- [ ] Remove Azure subscription service principals.
- [ ] Close or disable Azure DevOps organisation (if no other projects use it).
- [ ] Close Azure MSDN subscription (or allow credits to lapse without renewal).

#### 6.3 Repository cleanup

- [ ] Remove or archive `infra-pipeline.yaml`.
- [ ] Remove `terraform/components/game-server/` (game server already decommissioned; remove the Terraform component).
- [ ] Remove `terraform/components/cloud-vpn-gateway/` (decommissioned).
- [ ] Update `README.md` — remove Azure prerequisites, document new setup.
- [ ] Update Renovate config (`renovate.json`) — remove `azurerm` provider references.

#### 6.4 Post-migration review

- [ ] Cost comparison: Azure monthly spend vs new monthly spend.
- [ ] Document lessons learned.
- [ ] Update this execution plan with actual completion dates.

### Acceptance criteria

- [ ] Stable operation for 7+ days after full cutover.
- [ ] All Azure resources deleted (verified in Azure Portal).
- [ ] Azure subscription closed or credits lapsed.
- [ ] Cost baseline documented (before vs after).
- [ ] `README.md` updated with new architecture.

### Rollback (Phase 6)

At this stage, rollback to Azure is not feasible without re-provisioning. The 7-day soak period in 6.1 is the last opportunity to identify issues before decommissioning.

---

## PR Sequence

Following the issue requirement for small, reviewable PRs:

| PR | Content | Dependencies |
|---|---|---|
| PR 1 | This inventory + architecture docs (`docs/migration/`) | None (this PR) |
| PR 2 | Secrets decoupling — remove KV data sources; add Terraform variables | PR 1 |
| PR 3 | Terraform state migration to R2 or Azure Blob (`init.tf` backend changes) | PR 2 |
| PR 4 | DB backup migration — rclone replaces azcopy in Ansible playbooks | PR 3 |
| PR 5 | GitHub Actions CI/CD + ARC runners (replaces infra-pipeline.yaml) | PR 2–4 |
| PR 6 | Azure decommission — cleanup, README update, remove old components | PR 5 + 7-day soak |

> Note: PR 5 (Hetzner game server) has been removed from the sequence as game servers are already decommissioned.

Each PR must include:
- Change summary
- Risk assessment
- Rollback steps
- Evidence (test run logs / screenshots)

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Terraform state corruption during migration | Low | High | State file backup before each migration |
| GitHub Actions runner not available for on-prem jobs | Medium | High | Keep ADO pipeline active in parallel until ARC is stable |
| Twingate outage during pipeline run | Low | Medium | Add retry logic; Twingate SLA-backed |
| State backend locking not available (if R2 chosen) | Low | Medium | Use Azure Blob (new sub) or HCP Terraform for native locking — see `replacement-matrix.md` §2 |
| R2 credentials expiry | Low | Medium | Use long-lived tokens; add rotation reminder |
| PostgreSQL backup gap during azcopy→rclone transition | Low | Medium | Run both in parallel for one backup cycle |
| Azure Key Vault soft-delete prevents secret access after planned deletion | Low | Low | Phase 0 exports all secrets before deletion |

---

## Contacts and Owners

| Stream | Owner (placeholder) | Notes |
|---|---|---|
| Secrets migration | @bancey | Requires Key Vault access |
| Terraform state | @bancey | Requires Azure storage access |
| DB backups | @bancey | Requires Ansible + Proxmox access |
| Game server | @bancey | Requires Hetzner account |
| CI/CD | @bancey | Requires GitHub org admin |
| Azure cleanup | @bancey | Requires Azure subscription admin |
