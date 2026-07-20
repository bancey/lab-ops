# Docker Swarm Migration Plan (Raspberry Pi Lab)

## Scope
Migrate Raspberry Pi application deployment from host-local Docker Compose orchestration to Docker Swarm stacks, with Git-driven deployment workflows and documented rollback.

This plan intentionally keeps keepalived in place for edge VIP failover.

## Current-State Inventory

### Raspberry Pi deployment entrypoints
- `ansible/rpi-ha.yaml`
  - Installs prerequisites and Docker on `rpi` hosts.
  - Configures keepalived with `ansible/templates/keepalived.conf.j2`.
  - Deploys network and monitoring via role-managed compose files.
- `ansible/nut-server.yaml`
  - Configures UPS monitoring server on `gamora`.
- `ansible/scansnap.yaml`
  - Configures ScanSnap workflow on `gamora`.

### Legacy Compose definitions (removed)
- Previous files:
  - `ansible/roles/rpi-network/templates/network-compose.yaml.j2`
  - `ansible/roles/rpi-monitoring/templates/monitoring-compose.yaml.j2`
- These were replaced by:
  - `stacks/network.stack.yml.j2`
  - `stacks/monitoring.stack.yml.j2`

### Ansible inventory and role assets
- Inventory: `ansible/hosts.yaml` (Terraform-generated).
- Roles used by RPi HA path:
  - `ansible/roles/prep`
  - `ansible/roles/install-docker`
  - `ansible/roles/rpi-network`
  - `ansible/roles/rpi-monitoring`

### Deployment scripts/workflows/automation
- Azure DevOps pipeline: `infra-pipeline.yaml`
  - Runs `ansible/rpi-ha.yaml`, `ansible/nut-server.yaml`, `ansible/scansnap.yaml`.
- GitHub workflow: `.github/workflows/lint.yaml` (YAML lint only).
- Task automation: `Taskfile.yaml` (Flux bootstrap only; no Swarm tasks today).

### keepalived-related configuration found
- `ansible/rpi-ha.yaml`
- `ansible/haproxy.yaml`
- `ansible/postgresql.yaml`
- `ansible/mariadb.yaml`
- `ansible/templates/keepalived.conf.j2`
- `ansible/templates/keepalived-postgresql.conf.j2`
- `ansible/templates/keepalived-proxysql.conf.j2`
- `ansible/templates/postgresql-keepalived-notify.sh.j2`

## Target-State Architecture

### Node model (3 Raspberry Pis)
- Primary manager: first manager host in inventory/group vars (default: `thanos`).
- Additional manager: one secondary manager (recommended for 3-node quorum resilience).

Recommended default role split for 3 nodes:
- `thanos`: manager
- `nebula`: manager
- `gamora`: manager

### Scheduling model
- Swarm orchestration for compose-derived apps:
  - `rpi_network` stack
  - `rpi_monitoring` stack
- USB host specialization:
  - Scanner/UPS playbooks remain pinned to `gamora` as host-level services.
  - No swarm usb node labels or usb placement constraints are required.

### Edge failover posture
- keepalived remains authoritative for edge VIP failover (L2/L3).
- Swarm provides service scheduling and internal service-level balancing.
- No keepalived removal in this migration.

## Per-File Migration Map

### New files
- `stacks/network.stack.yml.j2`
  - Swarm stack template replacing network compose definition.
- `stacks/monitoring.stack.yml.j2`
  - Swarm stack template replacing monitoring compose definition.
- `ansible/group_vars/rpi_swarm.yaml.example`
  - Example swarm variables (manager, roles, stack names).
- `scripts/deploy-rpi-swarm.sh`
  - Git-driven deployment helper for repeatable stack deploy/update.
- `docs/swarm-ops-checklist.md`
  - Operational verification and troubleshooting checklist.

### Modified files
- `ansible/rpi-ha.yaml`
  - Add idempotent swarm init/join bootstrap.
  - Keep keepalived tasks.
  - Use Swarm deployment roles/tags for stacks.
- `ansible/roles/rpi-network/tasks/main.yaml`
  - Render/deploy stack file instead of compose file.
- `ansible/roles/rpi-monitoring/tasks/main.yaml`
  - Render/deploy stack file instead of compose file.
- `ansible/roles/rpi-network/README.md`
  - Swarm usage and operations updates.
- `ansible/roles/rpi-monitoring/README.md`
  - Swarm usage and operations updates.
- `ansible/README.md`
  - RPi path described as Swarm-based.
- `README.md`
  - Add top-level Swarm deployment flow and references.
- `.github/workflows/lint.yaml`
  - Add Swarm stack config validation.

### Removed legacy files
- `ansible/roles/rpi-network/templates/network-compose.yaml.j2`
- `ansible/roles/rpi-monitoring/templates/monitoring-compose.yaml.j2`

Rollback now relies on checking out a pre-migration git ref instead of in-repo compose templates.

## Rollout Sequence
1. Merge Swarm automation + docs.
2. Prepare inventory/group vars for 3-node swarm role mapping.
3. Run bootstrap playbook:
   - install Docker (idempotent)
   - initialize/join swarm
4. Deploy `rpi_network` stack.
5. Deploy `rpi_monitoring` stack.
6. Validate services and node placement.
7. Verify scanner and UPS workloads still run on `gamora`.
8. Execute one service update and rollback test.

## Rollback Approach

### Immediate rollback (service level)
- Use Swarm rollback for changed services:
  - `docker service rollback <stack>_<service>`

### Stack rollback (manifest level)
- Redeploy previous commit:
  - checkout previous git ref
  - redeploy stacks with `docker stack deploy -c ...`

### Compose fallback (migration escape hatch)
- If needed, disable/remove Swarm stacks and run previous compose-based deployment playbook version from a pre-migration commit.

### Network/failover rollback
- keepalived configuration is preserved throughout migration; no keepalived rollback expected.

## Known Caveats and Assumptions
- Host bind mounts remain host-local. Services using bind mounts must be constrained to nodes where required paths/devices exist.
- Privileged monitoring services (Alloy/cAdvisor) are retained with conservative Swarm settings.
- UPS and scanner automation is currently host-level Ansible/systemd, not compose-based; migration keeps that behavior and ensures `gamora` affinity policy is documented and preserved.
