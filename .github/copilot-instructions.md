# lab-ops Infrastructure Repository

Infrastructure as Code repository for managing a comprehensive lab environment spanning Azure cloud and on-premise Proxmox infrastructure using Terraform, Ansible, and Kubernetes with GitOps.

## Working Effectively

### Bootstrap Development Environment
Run these commands to set up your development environment with all required tools:

```bash
# Install Task automation tool
curl -sL https://github.com/go-task/task/releases/latest/download/task_linux_amd64.tar.gz | sudo tar -xzC /usr/local/bin/ task
sudo chmod +x /usr/local/bin/task

# Install Terraform
wget -q https://releases.hashicorp.com/terraform/1.9.4/terraform_1.9.4_linux_amd64.zip -O /tmp/terraform.zip
cd /tmp && unzip -o terraform.zip && sudo mv terraform /usr/local/bin/ && sudo chmod +x /usr/local/bin/terraform

# Install Flux CLI
curl -L https://github.com/fluxcd/flux2/releases/download/v2.3.0/flux_2.3.0_linux_amd64.tar.gz | tar xz
sudo mv flux /usr/local/bin/

# Install SOPS for secret management
wget https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 -O sops
sudo mv sops /usr/local/bin/ && sudo chmod +x /usr/local/bin/sops

# Install Age for encryption
wget https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-amd64.tar.gz -O - | tar xz
sudo mv age/age /usr/local/bin/ && sudo mv age/age-keygen /usr/local/bin/

# Verify installations
task --version && terraform --version && flux --version && sops --version && age --version
```

### Validate Repository Configuration
Always run these validation steps after making changes:

```bash
# Lint all YAML files
yamllint .

# Check Terraform formatting in all components
terraform fmt -check -recursive terraform/components/

# Validate Task configuration
task --list
```

All validation commands must pass before committing changes.

### Install Ansible Dependencies (Optional)
Ansible Galaxy requires internet connectivity to galaxy.ansible.com which may not be available in all environments.

```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```

If this fails with network errors, document it but continue—it's a known limitation in sandboxed environments.

## Repository Structure & Key Projects

### Core Infrastructure Components
- **`terraform/`** — Infrastructure as Code for Azure and Proxmox
  - **`components/`** — Deployable components: `cloud-vpn-gateway`, `dns`, `game-server`, `inventory`, `twingate`, `virtual-machines`
  - **`environments/`** — Environment-specific variable files (`prod`, `test`)
  - **`modules/`** — Reusable Terraform modules: `adguard`, `proxmox-ct`, `proxmox-vm`
- **`ansible/`** — Configuration management and provisioning
  - **`k3s.yaml`** — Kubernetes (K3s) cluster deployment
  - **`rpi-ha.yaml`** — Raspberry Pi HA and Twingate connector setup
  - **`nut-server.yaml`** / **`nut-client.yaml`** / **`nut-client-wanda.yaml`** — UPS (NUT) monitoring
  - **`haproxy.yaml`** — HAProxy load balancer
  - **`wings-node.yaml`** — Pterodactyl Wings game panel node
  - **`ado-agent.yaml`** — Azure DevOps self-hosted agent
  - **`mariadb.yaml`** / **`postgresql.yaml`** — Database provisioning
  - **`matter-server.yaml`** — Matter smart home server
  - **`requirements.yaml`** — Required Ansible collections and roles
- **`kubernetes/`** — GitOps-managed Kubernetes manifests
  - **`flux/`** — Flux GitOps configuration (`clusters/`, `repositories/`)
  - **`apps/`** — Application deployments per cluster (`base`, `minikube`, `tiny`, `wanda`)
  - **`app-dependencies/`** — Shared dependencies: controllers (cert-manager, Traefik, CSI NFS driver, Dragonfly, local-path-provisioner) and config (issuers, storage classes, secrets)
  - **`infrastructure/`** — Cluster networking (Cilium CNI, BGP peering, LoadBalancer IP pools)
  - **`bootstrap/`** — Bootstrap secrets and keys (SOPS encrypted)

### Key Files
- **`Taskfile.yaml`** — Task automation for Kubernetes bootstrap operations
- **`infra-pipeline.yaml`** — Azure DevOps pipeline for full infrastructure deployment
- **`.sops.yaml`** — SOPS configuration for Age-based secret encryption
- **`.yamllint.yaml`** — YAML linting rules
- **`renovate.json`** — Automated dependency management (Terraform, Kubernetes, Helm, Docker, Ansible)
- **`.mergify.yml`** — Mergify auto-approve rules for Renovate and Copilot PRs

## Deployment & Operations

### This repository is designed for Azure DevOps pipeline deployment
Most infrastructure operations cannot be performed locally due to dependencies on:
- Azure Key Vault for secrets (requires `bancey-vault` access)
- Twingate VPN connectivity for on-premise resources
- Azure service principal authentication
- On-premise Proxmox nodes and Raspberry Pi devices

### Local Operations (Safe to perform)
```bash
# Lint YAML files
yamllint .

# Format Terraform files (all components)
terraform fmt -recursive terraform/components/

# List available Task automation
task --list
```

### Kubernetes Bootstrap (Requires cluster access)
```bash
# Bootstrap Flux on an existing cluster
# REQUIRES: kubectl context configured, SOPS keys available, cluster connectivity
task bootstrap -- <cluster-name>
```

Valid cluster names correspond to directories under `kubernetes/flux/clusters/` (e.g., `minikube`, `tiny`, `wanda`). Note that `kubernetes/apps/base/` contains shared manifests inherited by clusters, not a deployable cluster itself.

### Azure DevOps Pipeline Operations
The primary deployment method uses `infra-pipeline.yaml` which orchestrates:
1. **Host connectivity checks** — Verifies on-premise hosts are online via Twingate
2. **Terraform deployments** — Provisions infrastructure across prod and test environments
3. **Ansible configuration** — Configures VMs, containers, UPS monitoring, and Raspberry Pi devices
4. **Kubernetes GitOps** — Applications deploy automatically via Flux on merge to main

## Validation & Testing

### After making changes, always:

1. **Validate YAML syntax**: `yamllint .`
2. **Check Terraform formatting**: `terraform fmt -check -recursive terraform/components/`
3. **Verify Task configuration**: `task --list`
4. **Review SOPS encrypted files**: Ensure no plaintext secrets are committed

### Security Validation
Never commit plaintext secrets. All sensitive data must be encrypted with SOPS:
```bash
grep -r "password\|secret\|key" --include="*.yaml" --include="*.yml" kubernetes/ ansible/ | grep -v ".sops.yaml"
```

### CI/CD Validation
The `.github/workflows/lint.yaml` workflow runs `yamllint .` on all pull requests targeting `main`.

## Common Tasks

### Adding New Infrastructure
1. Create or modify Terraform files in `terraform/components/<component>/`
2. Add environment variables in `terraform/environments/<env>/<env>.tfvars`
3. Validate: `terraform fmt -check terraform/components/<component>/`
4. Changes deploy via `infra-pipeline.yaml` on merge to main

### Adding New Kubernetes Applications
1. Create manifests in `kubernetes/apps/<cluster>/` (or `kubernetes/apps/base/` for shared apps)
2. Encrypt secrets with SOPS: `sops -e secret.yaml > secret.sops.yaml`
3. Flux automatically deploys changes after merge to main

### Managing Secrets
```bash
# Decrypt SOPS file for viewing (requires Age key)
sops -d kubernetes/bootstrap/sops-age-secret.sops.yaml

# Encrypt new secret (requires Age key)
sops -e new-secret.yaml > new-secret.sops.yaml
```

SOPS operations require the Age private key from Azure Key Vault.

## Troubleshooting & Limitations

### Safe Operations
- ✅ YAML linting and Terraform formatting
- ✅ Task automation listing
- ✅ Repository exploration and documentation updates
- ✅ Kubernetes manifest creation (without deployment)

### Requires Infrastructure Access
- ❌ Terraform planning/applying (requires Azure backend and service principal)
- ❌ Ansible playbook execution (requires Twingate VPN and SSH keys)
- ❌ Kubernetes cluster operations (requires kubectl context)
- ❌ SOPS encryption/decryption (requires Age private key from Key Vault)

## Quick Reference

### Repository Root Contents
```
.
├── .github/workflows/        # GitHub Actions (lint.yaml)
├── .gitignore
├── .mergify.yml              # Auto-approve rules
├── .sops.yaml                # SOPS encryption config
├── .vscode/                  # VS Code workspace settings
├── .yamllint.yaml            # YAML linting rules
├── README.md
├── Taskfile.yaml             # Task automation
├── ansible/                  # Ansible playbooks and roles
├── infra-pipeline.yaml       # Azure DevOps pipeline
├── kubernetes/               # GitOps Kubernetes manifests
├── renovate.json             # Dependency management
└── terraform/                # Terraform components, environments, modules
```

### Essential Commands
```bash
yamllint . && echo "YAML valid"
terraform fmt -check -recursive terraform/components/ && echo "Terraform formatted"
task --list && echo "Task configuration valid"
```