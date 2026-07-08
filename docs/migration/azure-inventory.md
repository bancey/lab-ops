# Azure Dependency Inventory

> Generated: 2026-07-08 | Repository: bancey/lab-ops

This document provides a complete inventory of every Azure service and dependency used in this repository.

---

## Summary

| Category | Service | Usage | Files |
|---|---|---|---|
| Secrets/Config | Azure Key Vault (`bancey-vault`) | Primary secret store for all Terraform components | Multiple `*.tf` files |
| Storage | Azure Blob Storage (`banceystatestor`) | Terraform remote state backend | All `init.tf` files |
| Storage | Azure Blob Storage (`banceyprodstor`) | PostgreSQL and MariaDB database backups | `ansible/postgresql.yaml`, `ansible/mariadb.yaml` |
| Compute | Azure Virtual Machines | Game server nodes (Pelican/Pterodactyl) | `terraform/components/game-server/` |
| Networking | Azure Virtual Network + Subnets | Game server network isolation | `terraform/components/game-server/networking.tf` |
| Networking | Azure Public IP | Game server public endpoints | `terraform/components/game-server/networking.tf` |
| Networking | Azure Network Security Group | Game server firewall rules | `terraform/components/game-server/networking.tf` |
| Networking | Azure VPN Gateway | Cloud VPN for hybrid connectivity (test + prod) | `terraform/components/cloud-vpn-gateway/` |
| Identity | Azure Active Directory / Entra ID | VM identity for Key Vault access, AAD login on game server VMs | `terraform/components/game-server/game-server-node.tf` |
| CI/CD | Azure DevOps Pipelines | Primary CI/CD orchestration | `infra-pipeline.yaml` |
| CI/CD | Azure DevOps Self-Hosted Agents | Pipeline execution on Kubernetes + on-prem VMs | `kubernetes/apps/base/azdevops/`, `ansible/ado-agent.yaml` |

---

## 1. Secrets / Config: Azure Key Vault

**Resource name:** `bancey-vault`  
**Resource group:** `common`  
**Usage:** Every Terraform component reads secrets from this vault at plan/apply time. The pipeline downloads secrets using `AzureCLI@2` tasks.

### Secrets stored in Key Vault

| Secret Name | Used By | Purpose |
|---|---|---|
| `Cloudflare-Lab-API-Token` | `dns`, `virtual-machines` | Cloudflare DNS management (lab zone) |
| `Cloudflare-Main-API-Token` | `dns`, `game-server` | Cloudflare DNS management (main zone) |
| `Cloudflare-Lab-Zone-ID` | `dns`, `virtual-machines` | Cloudflare lab zone identifier |
| `Cloudflare-Main-Zone-ID` | `dns`, `game-server` | Cloudflare main zone identifier |
| `Cloudflare-Lab-Zone-Name` | `dns`, `virtual-machines` | Cloudflare lab zone name |
| `Cloudflare-Main-Zone-Name` | `dns`, `game-server` | Cloudflare main zone name |
| `Adguard-Thanos-Host` | `dns` | AdGuard thanos instance host |
| `Adguard-Thanos-Username` | `dns` | AdGuard thanos instance username |
| `Adguard-Thanos-Password` | `dns` | AdGuard thanos instance password |
| `Adguard-Gamora-Host` | `dns` | AdGuard gamora instance host |
| `Adguard-Gamora-Username` | `dns` | AdGuard gamora instance username |
| `Adguard-Gamora-Password` | `dns` | AdGuard gamora instance password |
| `Twingate-URL` | `twingate` | Twingate network URL |
| `Twingate-API-Token` | `twingate` | Twingate API authentication |
| `Twingate-AzureDevOps-SA-Key` | `infra-pipeline.yaml` | Twingate service account for pipeline VPN |
| `Twingate-banceylab-connector-*` | `infra-pipeline.yaml` | Twingate connector tokens (Ansible) |
| `Wanda-Proxmox-URL` | `virtual-machines` | Wanda Proxmox cluster endpoint |
| `Wanda-Proxmox-Username` | `virtual-machines` | Wanda Proxmox credentials |
| `Wanda-Proxmox-Password` | `virtual-machines` | Wanda Proxmox credentials |
| `Tiny-Proxmox-URL` | `virtual-machines` | Tiny cluster Proxmox endpoint |
| `Tiny-Proxmox-Username` | `virtual-machines` | Tiny cluster Proxmox credentials |
| `Tiny-Proxmox-Password` | `virtual-machines` | Tiny cluster Proxmox credentials |
| `Hela-Proxmox-URL` | `virtual-machines` | Hela node Proxmox endpoint |
| `Loki-Proxmox-URL` | `virtual-machines` | Loki node Proxmox endpoint |
| `Thor-Proxmox-URL` | `virtual-machines` | Thor node Proxmox endpoint |
| `Lab-VM-Username` | `virtual-machines` | Default VM username |
| `Lab-VM-Password` | `virtual-machines` | Default VM password |
| `Game-Server-Ports` | `game-server` | Allowed port ranges for game server NSG |
| `Public-IP` | `dns`, `game-server` | Home/lab public IP for allowlisting |
| `GitHub-Bot-Private-Key` | `inventory` pipeline step | GitHub App private key for inventory |
| `GitHub-Bot-ID` | `inventory` | GitHub App ID |
| `GitHub-Bot-Installation-ID` | `inventory` | GitHub App installation ID |
| `Flux-Age-Key` | pipeline (`virtual-machines` step) | Age private key for SOPS decryption |
| `Packer-Private-Key` | pipeline (Ansible steps) | SSH private key for Ansible |
| `PostgreSQL-Superuser-Password` | `ansible/postgresql.yaml` | PostgreSQL superuser |
| `PostgreSQL-Replication-Password` | `ansible/postgresql.yaml` | PostgreSQL replication user |
| `PostgreSQL-Keepalived-Password` | `ansible/postgresql.yaml` | Keepalived VIP password |
| `PostgreSQL-Backup-SAS-Token` | `ansible/postgresql.yaml` | SAS token for Azure Blob backup uploads |
| `PostgreSQL-*-Password` (×6) | `ansible/postgresql.yaml` | Per-application DB passwords |
| `keepalived-pass` | `ansible/rpi-ha.yaml` | Keepalived shared secret |
| `BunkerWeb-*` (×4) | `ansible/rpi-ha.yaml` | BunkerWeb configuration secrets |
| `NUT-Admin-Password` | `ansible/nut-server.yaml` | NUT UPS admin password |
| `NUT-Monitor-Password` | `ansible/nut-server.yaml`, `nut-client.yaml` | NUT UPS monitor password |
| `Paperless-API-Token` | `ansible/scansnap.yaml` | Paperless-ngx API token |
| `Discord-Gatus-Webhook-URL` | `ansible/rpi-ha.yaml` | Gatus status webhook |

### Terraform files using Key Vault

| File | Purpose |
|---|---|
| `terraform/components/dns/interpolated-defaults.tf` | Reads Cloudflare, AdGuard, public IP secrets |
| `terraform/components/twingate/interpolated-defaults.tf` | Reads Twingate URL and API token |
| `terraform/components/twingate/connector.tf` | Writes Twingate connector tokens back to KV |
| `terraform/components/twingate/service_account.tf` | Writes Twingate SA key to KV |
| `terraform/components/game-server/interpolated-defaults.tf` | Reads game server configuration secrets |
| `terraform/components/virtual-machines/interpolated-defaults.tf` | Reads Proxmox credentials, VM credentials, Cloudflare tokens |
| `terraform/components/virtual-machines/vms-lxc-config.tf` | Reads Ansible secrets for VM provisioning |
| `terraform/components/inventory/interpolated-defaults.tf` | Reads GitHub App credentials |

---

## 2. Storage: Azure Blob Storage — Terraform State

**Storage account:** `banceystatestor`  
**Usage:** Remote backend for all Terraform state files

| Terraform Component | State file key |
|---|---|
| `inventory` | `tfstate/generate_ansible_inventory.tfstate` |
| `twingate` | `tfstate/prod_twingate.tfstate` |
| `dns` | `tfstate/prod_dns.tfstate` |
| `cloud-vpn-gateway` (test) | `tfstate/test_vpn_gateway.tfstate` |
| `cloud-vpn-gateway` (prod) | `tfstate/prod_vpn_gateway.tfstate` |
| `game-server` (test) | `tfstate/test_gameserver.tfstate` |
| `game-server` (prod) | `tfstate/prod_gameserver.tfstate` |
| `virtual-machines` (wanda) | `tfstate/wanda_virtual_machines.tfstate` |
| `virtual-machines` (tiny) | `tfstate/tiny_virtual_machines.tfstate` |

### Code references

All `init.tf` files contain:

```hcl
backend "azurerm" {}
```

Configured via `backendStorageAccount: banceystatestor` in `infra-pipeline.yaml`.

---

## 3. Storage: Azure Blob Storage — Database Backups

**Storage account:** `banceyprodstor`  
**Tool:** `azcopy` (downloaded at runtime)

### PostgreSQL backups

**File:** `ansible/postgresql.yaml` (lines 573–621)

```yaml
- name: Install azcopy
  # Downloads from aka.ms/downloadazcopy-v10-linux
- name: Upload backup to Azure Blob Storage
  # azcopy copy "${LOCAL_DIR}/" "https://${STORAGE_ACCOUNT}.blob.core.windows.net/..."
```

**Variables:**
- `backup_storage_account_name: banceyprodstor` (set via `prod.tfvars` Ansible arguments)
- `backup_sas_token`: read from Azure Key Vault secret `PostgreSQL-Backup-SAS-Token`

### MariaDB backups

**File:** `ansible/mariadb.yaml` (lines 436–485)

Same pattern as PostgreSQL — installs `azcopy` and uploads to Azure Blob Storage using SAS token.

---

## 4. Compute: Azure Virtual Machines — Game Server

**Resource group:** `games-prod-rg`, `games-test-rg`  
**Location:** `uksouth`  
**VM size:** `Standard_F2ams_v6`

### Azure resources provisioned

| Resource type | Name pattern | File |
|---|---|---|
| `azurerm_resource_group` | `games-{env}-rg` | `resource-group.tf` |
| `azurerm_public_ip` | `{name}-{env}-pip` | `networking.tf` |
| `azurerm_virtual_network` | `games-{env}-vnet` | `networking.tf` |
| `azurerm_subnet` | `games-{env}-{private,public}-subnet` | `networking.tf` |
| `azurerm_network_security_group` | `games-{env}-{private,public}-nsg` | `networking.tf` |
| `azurerm_network_security_rule` | Per-port rules from KV secret | `networking.tf` |
| `azurerm_subnet_network_security_group_association` | Associations | `networking.tf` |
| `azurerm_virtual_network_peering` | Peering to/from VPN VNet | `networking.tf` |
| Azure VM (via module) | `{name}-{env}` | `game-server-node.tf` |
| `azurerm_virtual_machine_extension` | `SetupTwingate` | `game-server-node.tf` |
| `azurerm_role_assignment` | Reader on `bancey-vault` | `game-server-node.tf` |

**External module:** `github.com/bancey/terraform-azurerm-game-server`

### Pipeline automation

`infra-pipeline.yaml` includes `AzureCLI@2` steps to:
- Start stopped VMs before Terraform apply (`az vm start`)
- Stop VMs after apply (`az vm deallocate`)

---

## 5. Networking: Azure VPN Gateway

**Component:** `terraform/components/cloud-vpn-gateway/`  
**Deployed environments:** test and prod  
**Purpose:** Hybrid cloud–on-premise VPN connectivity

Currently this component only has `init.tf` with the `azurerm` provider and `backend "azurerm"` configured. Additional resources are expected to be in the external module or managed separately.

---

## 6. Identity: Azure Active Directory / Entra ID

### VM managed identity

Game server VMs use system-assigned managed identities to access Key Vault:

```hcl
enable_aad_login = true
```

Role assignment: `Reader` on `bancey-vault` Key Vault.

### AAD group membership

```hcl
resource "azuread_group_member" "kv_reader" {
  group_object_id  = "9edd55d1-288c-482b-84a3-508efac9e683"
  member_object_id = module.game_server_node[each.key].vm_identity[0].principal_id
}
```

---

## 7. CI/CD: Azure DevOps

**File:** `infra-pipeline.yaml`  
**Service connection:** `MSDN New`  
**Pipeline type:** Azure DevOps YAML pipeline with templates from `bancey/azuredevops-lib`

### Pipeline stages

| Stage | Azure dependency |
|---|---|
| `check_hosts_online` | Key Vault (Twingate SA key), Twingate connect |
| `generate_ansible_inventory` | `AzureCLI@2` — downloads GitHub private key from KV |
| `prod_twingate` | Azure backend state, Key Vault secrets |
| `prod_dns` | Azure backend state, Key Vault secrets |
| `test_vpn_gateway` / `prod_vpn_gateway` | Azure backend state |
| `test_gameserver` / `prod_gameserver` | `AzureCLI@2` — VM start/stop, Azure backend, KV |
| `wanda_virtual_machines` / `tiny_virtual_machines` | `AzureCLI@2` — Age key from KV, Azure backend, KV secrets |
| `rpi_ansible` | Key Vault secrets (fetched via `AzureCLI@2` in template) |
| `nut_*_ansible`, `scansnap_ansible` | Key Vault secrets via `AzureCLI@2` |

### Azure DevOps Self-Hosted Agents

**Kubernetes deployment:** `kubernetes/apps/base/azdevops/deployment.yaml`  
**Secret:** `kubernetes/apps/tiny/azdevops-secret.sops.yaml`

Environment variables required:
- `AZP_URL` — Azure DevOps organisation URL
- `AZP_TOKEN` — Personal access token
- `AZP_POOL` — Agent pool name

**On-premise Ansible deployment:** `ansible/ado-agent.yaml`  
Uses `bancey/ado-agent` Docker image on `ado_agents` host group.

---

## 8. Operational / Scripts

| File | Azure dependency |
|---|---|
| `infra-pipeline.yaml` | Entire file — Azure DevOps YAML pipeline |
| `ansible/postgresql.yaml` | `azcopy` + Azure Blob Storage for backups |
| `ansible/mariadb.yaml` | `azcopy` + Azure Blob Storage for backups |
| `ansible/ado-agent.yaml` | Azure DevOps agent image and registration |
| `kubernetes/apps/base/azdevops/` | Azure DevOps agent Kubernetes deployment |
| `kubernetes/apps/tiny/azdevops-secret.sops.yaml` | Azure DevOps credentials (SOPS-encrypted) |
| `README.md` | Documents Azure subscription prerequisite |
| `terraform/environments/prod/prod.tfvars` | `backup_storage_account_name=banceyprodstor`, references Azure KV secret names |

---

## 9. Environment Variables / Pipeline Variables

| Variable | Value | Where used |
|---|---|---|
| `agentImage` | `ubuntu-latest` | `infra-pipeline.yaml` — Azure-hosted runner |
| `stateStorageAccount` | `banceystatestor` | `infra-pipeline.yaml` — Terraform state backend |
| `serviceConnection` | `MSDN New` | `infra-pipeline.yaml` — Azure service principal |
| `ANSIBLE_VAR_*` | From KV secrets | Terraform `local-exec` provisioner in `virtual-machines` |
| `backup_storage_account_name` | `banceyprodstor` | Ansible PostgreSQL/MariaDB backup |
| `backup_sas_token` | From KV | Ansible PostgreSQL/MariaDB backup |

---

## Dependency Graph

```
Azure DevOps (CI/CD)
  └─ Azure Key Vault (bancey-vault)
      ├─ Terraform state → Azure Blob (banceystatestor)
      ├─ Cloudflare secrets → DNS / Networking
      ├─ Proxmox secrets → Virtual Machines (on-prem)
      ├─ Twingate secrets → VPN connectivity
      ├─ Game server secrets → Azure VMs
      └─ DB passwords → Ansible PostgreSQL/MariaDB

Azure Blob Storage (banceyprodstor)
  └─ Database backups (PostgreSQL + MariaDB via azcopy)

Azure Virtual Machines (game-server)
  └─ Azure VNet + Subnets + NSG + Public IPs
  └─ Azure VPN Gateway (peering)
  └─ Azure AD / Entra ID (managed identity)

Azure DevOps Agents
  ├─ Kubernetes (tiny cluster)
  └─ On-premise (Ansible-managed)
```
