# lab-ops

Configuration as code for my lab environment which spans Azure & on-premise devices.

![Alt](https://repobeats.axiom.co/api/embed/5e99dee292ec3af09e50ecc4efd8e2be8c4b49da.svg "Repobeats analytics image")

## Deployment from Scratch

### Prerequisites
- Azure subscription and access to Azure Key Vault
- Proxmox nodes (on-prem)
- Raspberry Pi devices (for HA and Twingate connectors)
- [Task](https://taskfile.dev) installed for running automation tasks - not required but helpful.
- [Ansible](https://www.ansible.com/) and required collections/roles (see `ansible/requirements.yaml`)
- [Terraform](https://www.terraform.io/) and access to remote state

### 1. Add Required Secrets to Key Vault
Secrets must be created in Azure Key Vault (`bancey-vault`). Example command:

```bash
az keyvault secret set --vault-name bancey-vault --name <secret-name> --value <secret-value>
```

#### Required Secrets (referenced in Terraform and Azure DevOps):
- Proxmox URLs/Usernames/Passwords: `Wanda-Proxmox-URL`, `Wanda-Proxmox-Username`, `Wanda-Proxmox-Password`, etc.
- VM Credentials: `Lab-VM-Username`, `Lab-VM-Password`
- Cloudflare: `Cloudflare-Lab-API-Token`, `Cloudflare-Main-API-Token`, `Cloudflare-Lab-Zone-ID`, `Cloudflare-Main-Zone-ID`, `Cloudflare-Lab-Zone-Name`, `Cloudflare-Main-Zone-Name`
- Twingate: `Twingate-URL`, `Twingate-API-Token`, `Twingate-<connector>-Access-Token`, `Twingate-<connector>-Refresh-Token`, `Twingate-<service-account>-SA-Key`
- AdGuard: `Adguard-Thanos-Host`, `Adguard-Thanos-Username`, `Adguard-Thanos-Password`, `Adguard-Gamora-Host`, `Adguard-Gamora-Username`, `Adguard-Gamora-Password`
- GitHub Bot: `GitHub-Bot-ID`, `GitHub-Bot-Installation-ID`, `GitHub-Bot-Private-Key`
- SOPS/Flux: `Flux-Age-Key`
- Other: `Home-Public-IP`, `keepalived-pass`, `BunkerWeb-DB-Password`, `BunkerWeb-TOTP-Secrets`, `BunkerWeb-MGMT-Admin-Username`, `BunkerWeb-MGMT-Admin-Password`

### 2. Deploy Infrastructure
Deployment is automated via Azure DevOps pipelines (`infra-pipeline.yaml`). The pipeline will:
- Deploy Terraform components (Twingate, DNS, VPN Gateway, Game Server, Virtual Machines, etc.)
- Run Ansible playbooks (e.g., `ansible/rpi-ha.yaml` for Raspberry Pi HA setup, including Twingate connectors)
- Generate and apply Kubernetes manifests via Flux

### 3. Bootstrap Kubernetes Cluster
If you're using the Terraform to deploy Proxmox VMs for the control and worker nodes it includes Ansible automation to automatically provision and bootstrap the cluster with some basic configuration as well as Flux.

However, you can manually bootstrap the clusters using the taskfile. Replacing `<cluster-name>` with the name of your cluster, configuration will need to exist in the `kubernetes/flux/clusters` directory.

```bash
task bootstrap -- <cluster-name>
```

This will install Flux and apply the necessary secrets and sources for GitOps.

## Directory Structure

- `ansible/` - Ansible playbooks and roles for configuring VMs, containers, and Raspberry Pis (including Twingate connector setup)
- `docs/` - Documentation for specific features and integrations
  - `ipmi-sidecar.md` - IPMI sidecar setup and Home Assistant integration guide
- `kubernetes/` - GitOps-managed Kubernetes manifests, including app dependencies, apps, and infrastructure
- `terraform/` - Infrastructure as code for Azure, Proxmox, Twingate, DNS, etc.
  - `components/` - Reusable Terraform modules for each major infra component
  - `environments/` - Environment-specific variables and configuration (e.g., `prod`, `test`)
  - `modules/` - Custom Terraform modules (e.g., Proxmox VM/CT, AdGuard)
- `Taskfile.yaml` - Task automation for common workflows (e.g., bootstrapping Flux)
- `infra-pipeline.yaml` - Azure DevOps pipeline definition for full infra automation

## Notes
- Twingate connector deployment is now handled by the `ansible/rpi-ha.yaml` playbook. Manual Docker commands are no longer required.
- All secrets must be present in Key Vault before running the pipeline or Terraform/Ansible locally.
