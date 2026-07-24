# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Infrastructure-as-code for a personal lab spanning Azure and on-premise Proxmox/Raspberry Pi hardware. Three provisioning layers compose in sequence: **Terraform** (provisions VMs/CTs, DNS, Twingate, cloud resources) → **Ansible** (configures OS, clusters, databases, RPi Docker Swarm) → **Flux/Kubernetes** (GitOps app deployment). Deployment is orchestrated primarily by an Azure DevOps pipeline (`infra-pipeline.yaml`), not run ad hoc — most changes land via PR to `main` and roll out automatically.

## Commands

```bash
# YAML lint (required to pass CI on every PR — .github/workflows/lint.yaml)
yamllint .

# Terraform formatting (each component is a separate root module)
terraform fmt -check -recursive terraform/components/

# List Task automation targets
task --list

# Bootstrap Flux on a cluster (requires kubectl context + SOPS Age key already available)
task bootstrap -- <cluster-name>   # cluster-name matches a dir under kubernetes/flux/clusters/

# Ansible playbook syntax check (no inventory access needed)
ansible-playbook -i ansible/hosts.yaml --syntax-check ansible/<playbook>.yaml

# Validate Raspberry Pi swarm stack Jinja templates render correctly (CI: swarm-validate.yaml)
./scripts/validate-swarm-stack-templates.sh

# Deploy RPi swarm stacks (network + monitoring) via Ansible
./scripts/deploy-rpi-swarm.sh --manager thanos
ansible-playbook ansible/rpi-ha.yaml --tags network      # single stack
ansible-playbook ansible/rpi-ha.yaml --tags monitoring

# SOPS (requires Age private key, sourced from Azure Key Vault `bancey-vault`)
sops -d kubernetes/bootstrap/sops-age-secret.sops.yaml
sops -e new-secret.yaml > new-secret.sops.yaml
```

Most Terraform, Ansible, and Kubernetes operations against real infrastructure require Twingate VPN connectivity, Azure Key Vault access, or an Age key — these are **not available locally**; treat plan/apply/playbook-run/kubectl operations as CI/pipeline-only unless the user says otherwise. Linting, formatting, and template rendering/validation are the safe local operations.

## Architecture

### Kubernetes (`kubernetes/`) — Flux GitOps
- `flux/clusters/{minikube,tiny,wanda}` — per-cluster Flux Kustomizations; each cluster references `kubernetes/apps/base` plus its own overlay dir.
- `apps/base/<app>` — shared/base manifests (HelmRelease, Kustomization) for each application, cluster-agnostic.
- `apps/<cluster>/` — per-cluster overlay: patches, cluster-specific secrets (`*.sops.yaml`), Certificates, IngressRoutes, PVCs. `apps/tiny/kustomization.yaml` shows the pattern: base resources plus overlay-only patch/secret files layered on top; entries are commented out (not deleted) to disable an app while keeping history.
- `app-dependencies/controllers` — cluster-wide infra controllers: cert-manager, Traefik, csi-driver-nfs, Dragonfly (operator), local-path-provisioner.
- `app-dependencies/config` — cert-manager issuers, storage classes, Traefik dashboard auth.
- `infrastructure/` — Cilium CNI, BGP peering, LoadBalancer IP pools.
- `bootstrap/` — SOPS-encrypted Flux/Age bootstrap secrets, applied once via `task bootstrap`.
- `apps/base/` is not itself deployable — it's inherited by the real cluster dirs.

Conventions when adding a new app (see `.github/copilot-instructions.md` for the full walkthrough):
- New relational DB needs → add to the **Ansible-managed PostgreSQL cluster** (`ansible/postgresql.yaml`, `postgresql_databases` list) rather than deploying a DB in-cluster; wire the KeyVault secret via `terraform/environments/prod/prod.tfvars`. DB is reachable at `pgsql.heimelska.co.uk:5432`.
- New Redis/cache needs → use the existing **Dragonfly Operator** (create a `Dragonfly` CRD, e.g. `kubernetes/apps/base/pelican/dragonfly.yaml`), not a Redis container.
- New endpoints get a private DNS record in `terraform/environments/prod/dns.yaml` pointing at the cluster's LoadBalancer IP, named `<app>.<cluster>.heimelska.co.uk`.

### Terraform (`terraform/`)
- `components/{dns,inventory,twingate,virtual-machines}` — deployable root modules, each a distinct unit the pipeline plans/applies independently.
- `environments/{prod,test}` — tfvars per environment; `prod/dns.yaml` and `prod/prod.tfvars` are the ones most often touched when adding apps/hosts.
- `modules/{adguard,proxmox-ct,proxmox-vm}` — reusable modules consumed by `components/`.

### Ansible (`ansible/`)
Full architecture and conventions are documented in `ansible/README.md` — read it before making non-trivial Ansible changes. Key points not obvious from file listing:
- **RPi services run as Docker Swarm stacks**, not Kubernetes: `rpi-ha.yaml` bootstraps Docker/keepalived/Swarm, then deploys the `rpi_network` (AdGuard, Twingate connector, BunkerWeb) and `rpi_monitoring` (Gatus, Alloy, cAdvisor) stacks from Jinja templates in `stacks/*.stack.yml.j2` via the `rpi-network`/`rpi-monitoring` roles. Adding a swarm service means editing the relevant `stacks/<stack>.stack.yml.j2` template and the role's tasks, not writing Kubernetes YAML.
- `mariadb.yaml` and `postgresql.yaml` are large, deliberately inline (not role-extracted) playbooks setting up Galera / streaming-replication clusters with keepalived failover — this is an intentional stability choice, not an oversight; see `docs/mariadb-operations.md` and `docs/postgresql-operations.md` for runbooks.
- Secrets are pulled into playbooks via `lookup('ansible.builtin.file', 'filename')` from local files in the runner environment (not vars files) — e.g. `keepalived-pass`, `mariadb_root_password`, `Discord-Gatus-Webhook-URL`. These filenames map 1:1 to Key Vault secret names populated by the pipeline.
- Inventory groups worth knowing: `proxmox_tiny` (hela, loki, thor — hosts the tiny K3s cluster), `proxmox_wanda` (separate node), `rpi` (thanos, gamora — swarm cluster), `tiny_k3s_cluster`.
- Removed roles (`keepalived`, `setup-crafty-controller`) were deleted deliberately as dead code — don't resurrect their pattern without reason.

### Pipeline (`infra-pipeline.yaml`)
Azure DevOps pipeline: checks on-prem host connectivity via Twingate → Terraform per component/environment → Ansible configuration → Kubernetes apps roll out automatically via Flux once manifests land on `main`. This is the source of truth for deployment order/dependencies between components.

### Secrets
All secrets originate in Azure Key Vault `bancey-vault` and flow into: Terraform (as data sources), Ansible (as lookup'd local files during the pipeline run), and Kubernetes (as SOPS-encrypted `*.sops.yaml` manifests, decrypted in-cluster via Flux + the Age key from `kubernetes/bootstrap`). Never write plaintext secrets into any of these three layers — always the SOPS/`.sops.yaml` form for Kubernetes.

## Validation before considering a change done
1. `yamllint .`
2. `terraform fmt -check -recursive terraform/components/` (if Terraform touched)
3. `ansible-playbook --syntax-check` the relevant playbook (if Ansible touched)
4. `./scripts/validate-swarm-stack-templates.sh` (if `stacks/`, `rpi-ha.yaml`, or the rpi-network/rpi-monitoring roles touched — this is what CI's `swarm-validate.yaml` runs, gated on those paths)
