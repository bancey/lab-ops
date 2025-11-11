# RPi Network Role

This Ansible role manages the networking services Docker Compose stack for Raspberry Pi hosts.

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

The Docker Compose file is deployed to:
```
/opt/compose/network/docker-compose.yaml
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
docker compose -f /opt/compose/network/docker-compose.yaml ps

# Restart services
docker compose -f /opt/compose/network/docker-compose.yaml restart

# View logs
docker compose -f /opt/compose/network/docker-compose.yaml logs -f

# Stop stack
docker compose -f /opt/compose/network/docker-compose.yaml down

# Start stack
docker compose -f /opt/compose/network/docker-compose.yaml up -d
```

## Dependencies

- Docker and Docker Compose plugin installed
- `community.docker` Ansible collection

## Directory Structure

```
/opt/compose/network/          # Stack compose file location
/opt/adguard/config/           # AdGuard configuration
/opt/adguard/work/             # AdGuard working directory
```
