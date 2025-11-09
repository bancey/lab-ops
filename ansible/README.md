# Ansible Playbooks and Roles

This directory contains Ansible playbooks and roles for managing the lab infrastructure.

## Raspberry Pi Docker Compose Deployment

The Raspberry Pi hosts use a modular Docker Compose deployment strategy managed by Ansible. Services are organized into logical stacks that can be deployed, managed, and updated independently.

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
- **`haproxy.yaml`**: HAProxy load balancer setup
- **`ado-agent.yaml`**: Azure DevOps agent deployment
- **`wings-node.yaml`**: Pterodactyl Wings node setup

## Roles

Reusable Ansible roles are located in the `roles/` directory:

- **`prep`**: System preparation (package installation, configuration)
- **`install-docker`**: Docker installation and setup
- **`keepalived`**: Keepalived HA configuration
- **`rpi-network`**: Raspberry Pi network stack
- **`rpi-monitoring`**: Raspberry Pi monitoring stack
- **`setup-wings`**: Pterodactyl Wings setup
- **`setup-crafty-controller`**: Minecraft server controller
- **`run-ado-agent-container`**: Azure DevOps agent container

Each role contains its own README with detailed documentation.
