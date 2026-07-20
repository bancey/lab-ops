# RPi Network Role

This Ansible role manages the networking services Docker Swarm stack for Raspberry Pi hosts.

## Services

This stack includes the following services:

- **AdGuard Home** (`adguard`): DNS server with ad-blocking capabilities
  - Ports: 53 (DNS), 8000 (Web UI)
  - Volumes: `/opt/adguard/config`, `/opt/adguard/work`

- **Twingate Connector** (`twingate`): Zero-trust VPN connector
  - Network mode: bridge
  - Environment: Configured via playbook variables

- **BunkerWeb** (`bunkerweb`): Security-focused reverse proxy
  - Ports: 80, 443, 5000
  - Environment: Configurable API whitelist

## Stack Location

The rendered Docker Swarm stack file is deployed to:
```
/opt/stacks/network.stack.yml
```

## Variables

Required variables (passed from playbook):
- `twingate`: Dictionary containing network and per-host tokens
- `twingate[inventory_hostname].refresh_token`: Twingate refresh token
- `twingate[inventory_hostname].access_token`: Twingate access token
- `twingate.network`: Twingate network name

## Usage

### Deploy the stack
```bash
ansible-playbook rpi-ha.yaml --tags network
```

### Manage the stack manually on the host
```bash
# Check status
docker service ls | grep rpi_network

# Reconcile stack
docker stack deploy -c /opt/stacks/network.stack.yml rpi_network

# View logs
docker service logs -f rpi_network_adguard

# Remove stack
docker stack rm rpi_network
```

## Dependencies

- Docker Engine with Swarm enabled

## Directory Structure

```
/opt/stacks/network.stack.yml  # Rendered stack manifest on manager
/opt/adguard/config/           # AdGuard configuration
/opt/adguard/work/             # AdGuard working directory
```
