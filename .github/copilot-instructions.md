# lab-ops Infrastructure Repository

Infrastructure as Code repository for managing a comprehensive lab environment spanning Azure cloud and on-premise Proxmox infrastructure using Terraform, Ansible, and Kubernetes with GitOps.

**ALWAYS reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

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

Installation takes approximately 2-3 minutes total. **NEVER CANCEL** during tool installation.

### Validate Repository Configuration
Always run these validation steps after making changes:

```bash
# Lint all YAML files - takes ~6 seconds
yamllint .

# Check Terraform formatting in all components - takes ~10 seconds per component
find terraform/components -name "*.tf" -exec terraform fmt -check {} \;

# Validate Task configuration - takes <1 second
task --list
```

**CRITICAL**: All validation commands must pass before committing changes.

### Install Ansible Dependencies (Optional)
**NOTE**: Ansible Galaxy requires internet connectivity to galaxy.ansible.com which may not be available in all environments.

```bash
# Try to install Ansible collections - may fail due to network restrictions
ansible-galaxy collection install -r ansible/requirements.yaml
```

If this fails with network errors, document it but continue - it's a known limitation in sandboxed environments.

## Repository Structure & Key Projects

### Core Infrastructure Components
- **`terraform/`** - Infrastructure as Code for Azure and Proxmox
  - **`components/`** - Reusable modules (Twingate, DNS, VPN Gateway, Game Server, Virtual Machines)
  - **`environments/`** - Environment-specific configurations (prod, test)
  - **`modules/`** - Custom modules for Proxmox VM/CT and AdGuard
- **`ansible/`** - Configuration management and provisioning
  - **`k3s.yaml`** - Kubernetes cluster deployment playbook
  - **`rpi-ha.yaml`** - Raspberry Pi HA and Twingate connector setup
  - **`requirements.yaml`** - Required Ansible collections and roles
- **`kubernetes/`** - GitOps-managed Kubernetes manifests
  - **`flux/`** - Flux GitOps configuration
  - **`apps/`** - Application deployments
  - **`infrastructure/`** - Infrastructure services (monitoring, ingress, etc.)
  - **`bootstrap/`** - Bootstrap secrets and keys (SOPS encrypted)

### Key Files
- **`Taskfile.yaml`** - Task automation for Kubernetes bootstrap operations
- **`infra-pipeline.yaml`** - Azure DevOps pipeline for full infrastructure deployment
- **`.sops.yaml`** - SOPS configuration for secret encryption
- **`.yamllint.yaml`** - YAML linting configuration
- **`renovate.json`** - Dependency management configuration

## Deployment & Operations

### **CRITICAL LIMITATION**: This repository is designed for Azure DevOps pipeline deployment
**Most infrastructure operations CANNOT be performed locally** due to dependencies on:
- Azure Key Vault for secrets (requires `bancey-vault` access)
- Twingate VPN connectivity for on-premise resources
- Azure service principal authentication
- On-premise Proxmox nodes and Raspberry Pi devices

### Local Operations (Safe to perform)
```bash
# Lint YAML files - takes 6 seconds
yamllint .

# Format Terraform files - takes 10 seconds per component
terraform fmt terraform/components/dns/
terraform fmt terraform/components/twingate/
terraform fmt terraform/components/virtual-machines/

# List available Task automation - takes <1 second
task --list

# View Terraform configuration (no state access)
terraform -chdir=terraform/components/dns fmt -check
```

### Kubernetes Bootstrap (Requires cluster access)
```bash
# Bootstrap Flux on an existing cluster - takes 30-60 seconds if cluster is accessible
# REQUIRES: kubectl context configured, SOPS keys available, cluster connectivity
task bootstrap -- <cluster-name>
```

**WARNING**: This command will fail without proper Kubernetes cluster access and SOPS keys.

### Azure DevOps Pipeline Operations
The primary deployment method uses `infra-pipeline.yaml` which orchestrates:
1. **Twingate connectivity** - Establishes VPN to lab resources
2. **Terraform deployments** - Provisions infrastructure across multiple environments  
3. **Ansible configuration** - Configures VMs, containers, and Raspberry Pi devices
4. **Kubernetes GitOps** - Deploys applications via Flux

**Pipeline timing expectations**:
- **Full pipeline**: 45-90 minutes total. **NEVER CANCEL** Azure DevOps pipeline runs.
- **Terraform components**: 10-30 minutes each depending on complexity
- **Ansible playbooks**: 15-45 minutes depending on target hosts
- **Host connectivity checks**: 2-5 minutes per environment

## Validation & Testing

### Manual Validation Requirements
After making changes, **ALWAYS**:

1. **Validate YAML syntax**: `yamllint .` - must complete without errors
2. **Check Terraform formatting**: `terraform fmt -check terraform/components/*/` - must show no changes needed
3. **Verify Task configuration**: `task --list` - must show available tasks
4. **Review SOPS encrypted files**: Ensure no plaintext secrets are committed

### **CRITICAL**: Security Validation
**NEVER commit plaintext secrets**. All sensitive data must be encrypted with SOPS:
```bash
# Check for potential plaintext secrets before committing
grep -r "password\|secret\|key" --include="*.yaml" --include="*.yml" kubernetes/ ansible/ | grep -v ".sops.yaml"
```

### CI/CD Validation  
The `.github/workflows/lint.yaml` workflow runs on all pull requests:
```bash
# This is what CI runs - ensure it passes locally
yamllint .
```

**Build timing**: CI lint job takes 30-60 seconds. **NEVER CANCEL** the GitHub Actions workflow.

## Common Tasks & Expected Behavior

### Adding New Infrastructure
1. **Terraform changes**: Modify files in `terraform/components/`
2. **Validate locally**: `terraform fmt terraform/components/<component>/`
3. **Azure DevOps deployment**: Changes deploy via `infra-pipeline.yaml` on merge to main

### Adding New Kubernetes Applications  
1. **Create manifests**: Add to `kubernetes/apps/<cluster>/`
2. **Encrypt secrets**: Use SOPS for sensitive data: `sops -e secret.yaml > secret.sops.yaml`
3. **GitOps deployment**: Flux automatically deploys changes within 5-10 minutes

### Managing Secrets
```bash
# Decrypt SOPS file for viewing (requires Age key)
sops -d kubernetes/bootstrap/sops-age-secret.sops.yaml

# Encrypt new secret (requires Age key)  
sops -e new-secret.yaml > new-secret.sops.yaml
```

**NOTE**: SOPS operations require the Age private key from Azure Key Vault.

## Troubleshooting & Limitations

### Known Network Dependencies
- **Ansible Galaxy**: May fail in sandboxed environments - this is expected
- **Terraform init**: Requires Azure backend configuration - will prompt for input locally
- **Azure Key Vault**: All secrets stored remotely - local SOPS operations require key access
- **On-premise connectivity**: Twingate VPN required for Proxmox and Raspberry Pi access

### Safe Operations
- ✅ YAML linting and Terraform formatting
- ✅ Task automation listing  
- ✅ Repository exploration and documentation updates
- ✅ Kubernetes manifest creation (without deployment)

### Requires Infrastructure Access
- ❌ Terraform planning/applying
- ❌ Ansible playbook execution
- ❌ Kubernetes cluster operations  
- ❌ SOPS encryption/decryption (without keys)
- ❌ Pipeline execution (Azure DevOps only)

## Timing Expectations & Timeout Guidelines

**NEVER CANCEL** commands that are still running. Set appropriate timeouts:

- **yamllint**: 10 seconds (use 30s timeout)
- **terraform fmt**: 15 seconds per component (use 60s timeout)  
- **task commands**: 30 seconds (use 60s timeout)
- **Tool installation**: 3 minutes total (use 300s timeout)
- **Ansible operations**: 15-45 minutes (use 3600s timeout if attempting)
- **Terraform operations**: 10-30 minutes (use 1800s timeout if attempting)
- **Pipeline operations**: 45-90 minutes (NEVER CANCEL in Azure DevOps)

**When in doubt, wait longer rather than cancelling operations.**

## Quick Reference

### Repository Root Contents
```
.
├── README.md                  # Main documentation
├── Taskfile.yaml             # Task automation 
├── infra-pipeline.yaml       # Azure DevOps pipeline
├── .github/workflows/        # GitHub Actions
├── .sops.yaml               # SOPS configuration
├── .yamllint.yaml           # Linting rules
├── ansible/                 # Configuration management
├── kubernetes/              # GitOps manifests  
└── terraform/               # Infrastructure as Code
```

### Essential Commands
```bash
# Quick validation workflow
yamllint . && echo "YAML valid"
terraform fmt -check terraform/components/*/ && echo "Terraform formatted"
task --list && echo "Task configuration valid"
```

**Always validate your changes locally before pushing to ensure CI passes.**