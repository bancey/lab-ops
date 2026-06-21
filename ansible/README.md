# Ansible Playbooks and Roles

This directory contains Ansible playbooks and roles for managing the lab infrastructure.

## Raspberry Pi Docker Compose Deployment

The Raspberry Pi hosts use a modular Docker Compose deployment strategy managed by Ansible. Services are organized into logical stacks that can be deployed, managed, and updated independently.

**⚠️ Migrating from the old monolithic stack?** See [MIGRATION.md](MIGRATION.md) for step-by-step migration instructions to avoid service conflicts.

### Architecture

Services are split into the following stacks:

#### Network Stack (`rpi-network` role)
Manages core networking services:
- **AdGuard Home**: DNS server with ad-blocking
- **Twingate Connector**: Zero-trust VPN connectivity
- **BunkerWeb**: Security-focused reverse proxy

Deployed to: `/opt/compose/network/docker-compose.yaml`

#### Monitoring Stack (`rpi-monitoring` role)
Manages observability and monitoring services:
- **Gatus**: Health check and status monitoring
- **Grafana Alloy**: Observability data collector
- **cAdvisor**: Container metrics exporter
- **AdGuard Exporter**: Prometheus exporter for AdGuard metrics

Deployed to: `/opt/compose/monitoring/docker-compose.yaml`

### Playbook Structure

The `rpi-ha.yaml` playbook is organized into three plays:

1. **System setup**: Installs Docker, configures keepalived for HA
2. **Network stack deployment**: Deploys networking services
3. **Monitoring stack deployment**: Deploys monitoring services

### Usage

#### Deploy all stacks
```bash
ansible-playbook ansible/rpi-ha.yaml
```

#### Deploy only the network stack
```bash
ansible-playbook ansible/rpi-ha.yaml --tags network
```

#### Deploy only the monitoring stack
```bash
ansible-playbook ansible/rpi-ha.yaml --tags monitoring
```

### Managing Stacks on Hosts

Once deployed, each stack can be managed independently on the Raspberry Pi hosts:

#### Network Stack
```bash
# Check status
docker compose -f /opt/compose/network/docker-compose.yaml ps

# View logs
docker compose -f /opt/compose/network/docker-compose.yaml logs -f

# Restart a specific service
docker compose -f /opt/compose/network/docker-compose.yaml restart adguard

# Restart entire stack
docker compose -f /opt/compose/network/docker-compose.yaml restart
```

#### Monitoring Stack
```bash
# Check status
docker compose -f /opt/compose/monitoring/docker-compose.yaml ps

# View logs for specific service
docker compose -f /opt/compose/monitoring/docker-compose.yaml logs -f alloy

# Restart a specific service
docker compose -f /opt/compose/monitoring/docker-compose.yaml restart gatus

# Restart entire stack
docker compose -f /opt/compose/monitoring/docker-compose.yaml restart
```

### Adding New Services

To add a new service:

1. **Determine the appropriate stack** (network, monitoring, or create a new one)
2. **Update the compose template** in `ansible/roles/rpi-<stack>/templates/<stack>-compose.yaml.j2`
3. **Add any required directories** to the role's tasks in `ansible/roles/rpi-<stack>/tasks/main.yaml`
4. **Add variables** to the playbook if needed
5. **Update documentation** in the role's README.md

### Creating a New Stack

To create a new logical stack:

1. **Create role structure**:
   ```bash
   mkdir -p ansible/roles/rpi-<name>/{tasks,templates,defaults}
   ```

2. **Create the compose template**:
   `ansible/roles/rpi-<name>/templates/<name>-compose.yaml.j2`

3. **Create role tasks**:
   `ansible/roles/rpi-<name>/tasks/main.yaml`

4. **Add to playbook**:
   Add a new play in `rpi-ha.yaml` that includes your role

5. **Document**:
   Create `ansible/roles/rpi-<name>/README.md`

### Benefits of Modular Approach

- **Independent lifecycles**: Update or restart one stack without affecting others
- **Easier troubleshooting**: Logs and issues are isolated to specific stacks
- **Better maintainability**: Changes to one service group don't risk affecting others
- **Selective deployment**: Deploy only the stacks you need using tags
- **Clear organization**: Services are grouped by function, making the codebase easier to understand

## Other Playbooks

- **`k3s.yaml`**: Kubernetes cluster deployment
- **`k3s-uninstall.yaml`**: Kubernetes cluster removal
- **`haproxy.yaml`**: HAProxy load balancer setup with automatic failover
- **`mariadb.yaml`**: MariaDB Galera cluster setup with PXC replication
- **`postgresql.yaml`**: PostgreSQL streaming replication cluster with failover
- **`ado-agent.yaml`**: Azure DevOps agent deployment in Docker
- **`wings-node.yaml`**: Pterodactyl Wings game server node setup
- **`nut-server.yaml`**: NUT UPS monitoring server setup
- **`nut-client.yaml`**: NUT UPS monitoring client setup (targets both proxmox_tiny and proxmox_wanda)
- **`matter-server.yaml`**: Matter smart home server deployment

## Roles

Reusable Ansible roles are located in the `roles/` directory:

### Active Roles
- **`prep`**: System preparation (package installation, package updates, configuration)
- **`install-docker`**: Docker installation and setup
- **`rpi-network`**: Raspberry Pi network stack (AdGuard, Twingate, BunkerWeb)
- **`rpi-monitoring`**: Raspberry Pi monitoring stack (Gatus, Alloy, cAdvisor)
- **`setup-wings`**: Pterodactyl Wings game server setup
- **`setup-nut-client`**: NUT UPS client configuration
- **`setup-nut-server`**: NUT UPS server configuration
- **`run-ado-agent-container`**: Azure DevOps agent Docker container orchestration

Each role contains its own README with detailed documentation.

### Removed Roles
The following roles have been removed as they are no longer used:
- **`keepalived`** (removed): Inline keepalived configuration is handled within playbooks (haproxy, postgresql, rpi-ha)
- **`setup-crafty-controller`** (removed): Minecraft Crafty controller role (unused)

## Templates

### Shared Templates (`ansible/templates/`)

Templates used across multiple playbooks and roles:

#### Keepalived (Virtual IP Failover)
- `keepalived.conf.j2`: Generic virtual IP configuration
- `keepalived-postgresql.conf.j2`: PostgreSQL-specific failover configuration
- `keepalived-proxysql.conf.j2`: ProxySQL HA configuration

#### PostgreSQL
- `postgresql.conf.j2`: PostgreSQL server configuration
- `pg_hba.conf.j2`: PostgreSQL host-based authentication
- `pgbouncer.ini.j2`: PgBouncer connection pooler configuration
- `check-postgresql.sh.j2`: PostgreSQL health check script
- `postgresql-keepalived-notify.sh.j2`: Keepalived failover notification script

#### MariaDB
- `galera.cnf.j2`: Galera cluster configuration

#### Monitoring
- `alloy-config.alloy.j2`: Grafana Alloy collector base configuration
- `alloy-mariadb.alloy.j2`: Alloy scrape configuration for MariaDB metrics
- `alloy-proxysql.alloy.j2`: Alloy scrape configuration for ProxySQL metrics

#### HAProxy
- `tiny-haproxy.cfg.j2`: HAProxy load balancer configuration

#### ProxySQL
- `proxysql.cnf.j2`: ProxySQL configuration
- `check-proxysql.sh.j2`: ProxySQL health check script

#### Kubernetes
- `coredns-custom.yaml`: CoreDNS custom configuration for K3s
- `cluster-admins.yaml`: Kubernetes RBAC admin bindings

### Role-Specific Templates

Templates stored within individual roles' `templates/` directories:

#### `setup-nut-client` Role
- `nut.conf.j2`: NUT daemon configuration
- `upsmon.conf.j2`: NUT monitoring client configuration

#### `setup-nut-server` Role
- `nut.conf.j2`: NUT daemon configuration
- `ups.conf.j2`: UPS hardware configuration
- `upsd.conf.j2`: NUT server configuration
- `upsd.users.j2`: NUT user definitions
- `upsmon.conf.j2`: NUT monitoring configuration

#### `rpi-network` Role
- `network-compose.yaml.j2`: Docker Compose for networking services

#### `rpi-monitoring` Role
- `monitoring-compose.yaml.j2`: Docker Compose for monitoring services
- `gatus-config.yaml.j2`: Gatus health check configuration

#### `setup-wings` Role
- `cloudflare.ini.j2`: Cloudflare DNS ACME configuration
- `wings.service`: Systemd service file

## Inventory Structure

See `hosts.yaml` for full inventory definition. Key groups:

- **`proxmox_tiny`**: Proxmox hypervisors managing the tiny K3s cluster (hela, loki, thor)
- **`proxmox_wanda`**: Wanda Proxmox hypervisor (separate node)
- **`rpi`**: Raspberry Pi cluster nodes (thanos, gamora) for HA and monitoring
- **`tiny_k3s_cluster`**: Kubernetes cluster configuration with OIDC, Cilium CNI, custom arguments
- **Database clusters**: MariaDB, PostgreSQL, ProxySQL node groups

## Recent Cleanup & Refactoring

### 2025 Consolidation
This Ansible configuration has been refined from ~3 years of evolution:

#### Removed Dead Code
- Deleted unused role: `setup-crafty-controller` (no playbooks referenced it)
- Deleted unused role: `keepalived` (logic kept inline in playbooks to avoid unnecessary abstraction)
- Deleted unused templates: `frr.conf`, `rpi-docker-compose.yaml.j2`

#### Consolidated Playbooks
- Merged separate `nut-client.yaml` and `nut-client-wanda.yaml` into single `nut-client.yaml`
- Updated to target both `proxmox_tiny` and `proxmox_wanda` inventory groups
- Simplified Azure DevOps pipeline (`infra-pipeline.yaml`) to use single NUT client job

#### Future Refactoring Opportunities
The following are noted as candidates for future improvements but remain in their current form to maintain stability:
- **Inline database tasks**: `mariadb.yaml` and `postgresql.yaml` contain 600+ lines of inline tasks each
  - Could be refactored into dedicated roles (e.g., `setup-mariadb-galera`, `setup-postgresql-replication`)
  - Current approach works well but future extraction would improve modularity
- **Keepalived configuration**: Currently inline in `haproxy.yaml`, `postgresql.yaml`, `rpi-ha.yaml`
  - Could be unified in a single parameterized role if needed
  - Currently kept inline to avoid unnecessary role abstraction

## Best Practices

### Variable Management
- Secrets are loaded via `lookup('ansible.builtin.file', 'filename')` from local files in the runner environment
- Files required: `keepalived-pass`, `mariadb_root_password`, `mariadb_galera_password`, `postgresql_superuser_password`, `postgresql_replication_password`, `keepalived_postgresql_pass`, `backup_sas_token`, `NUT-Admin-Password`, `NUT-Monitor-Password`, `Discord-Gatus-Webhook-URL`
- These should be in `.gitignore` and managed securely in your runner environment

### Template Organization
- Shared templates in `/ansible/templates/` organized by service/purpose
- Role-specific templates in `roles/<role>/templates/` for templates unique to that role
- Configuration files in `files/` subdirectories for static content (e.g., systemd services)

### Playbook Conventions
- All playbooks use `become: true` and `become_user: root` for privilege escalation
- `gather_facts: true` used by default for system information gathering
- External roles (like `xanmanning.k3s`) pinned to specific versions in `requirements.yaml`

## Troubleshooting

### Ansible Galaxy Dependencies
Installation of collections requires internet access:
```bash
ansible-galaxy collection install -r ansible/requirements.yaml
```
If this fails in restricted environments, install requirements manually or skip (known limitation).

### Syntax Validation
Validate all playbooks before deployment:
```bash
for playbook in ansible/*.yaml; do
  ansible-playbook --syntax-check "$playbook"
done
```

### Inventory Validation
List all hosts and groups:
```bash
ansible-inventory --list
```

## Files

All playbook files are YAML-based with comprehensive error handling and idempotent task design.
