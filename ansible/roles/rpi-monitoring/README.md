# RPi Monitoring Role

This Ansible role manages the monitoring and observability Docker Compose stack for Raspberry Pi hosts.

## Services

This stack includes the following services:

- **AdGuard Exporter** (`adguard_exporter`): Prometheus exporter for AdGuard Home metrics
  - Port: 9618
  - Connects to: AdGuard Home at 10.151.14.4:8000 (VIP)

- **Gatus** (`gatus`): Health check and status monitoring
  - Port: 8080
  - Volumes: `/opt/gatus/config`, `/opt/gatus/data`

- **Grafana Alloy** (`alloy`): Observability data collector
  - Port: 12345
  - Volumes: Mounts host system directories for metrics collection
  - Privileged: Yes (required for system metrics)

- **cAdvisor** (`cadvisor`): Container metrics exporter
  - Port: 8081
  - Volumes: Mounts host system directories
  - Privileged: Yes (required for container metrics)

## Stack Location

The Docker Compose file is deployed to:
```
/opt/compose/monitoring/docker-compose.yaml
```

## Variables

Required variables (passed from playbook):
- `adguard_username`: Username for AdGuard Home API access
- `adguard_password`: Password for AdGuard Home API access

Optional variables (with defaults):
- `gatus_config_file`: Gatus config file name (default: `gatus-config.yaml` - uses file from role's `files/` directory)
- `alloy_config_template`: Alloy config template name (default: `alloy-config.alloy.j2` - uses template from role's `templates/` directory)

To use custom configuration files, override these variables in your playbook:
```yaml
- role: rpi-monitoring
  vars:
    # Absolute paths or relative paths (starting with ./ or ../) are supported
    gatus_config_file: "/path/to/custom/gatus-config.yaml"
    alloy_config_template: "/path/to/custom/alloy-config.alloy.j2"
```

Note: When using custom paths, they must be absolute paths (e.g., `/path/to/file`) or relative paths starting with `./` or `../`. The paths should point to files on the Ansible control node.

## Usage

### Deploy the stack
```bash
ansible-playbook rpi-ha.yaml --tags monitoring
```

### Manage the stack manually on the host
```bash
# Check status
docker compose -f /opt/compose/monitoring/docker-compose.yaml ps

# Restart services
docker compose -f /opt/compose/monitoring/docker-compose.yaml restart

# View logs
docker compose -f /opt/compose/monitoring/docker-compose.yaml logs -f

# Restart specific service
docker compose -f /opt/compose/monitoring/docker-compose.yaml restart alloy

# Stop stack
docker compose -f /opt/compose/monitoring/docker-compose.yaml down

# Start stack
docker compose -f /opt/compose/monitoring/docker-compose.yaml up -d
```

## Dependencies

- Docker and Docker Compose plugin installed
- `community.docker` Ansible collection
- Gatus configuration file
- Alloy configuration file

## Directory Structure

```
/opt/compose/monitoring/       # Stack compose file location
/opt/gatus/config/             # Gatus configuration
/opt/gatus/data/               # Gatus data directory
/opt/alloy/config/             # Alloy configuration
```

## Notes

- AdGuard Exporter connects to the AdGuard Home service via the VIP (10.151.14.4:8000)
- Both Alloy and cAdvisor require privileged mode to collect system and container metrics
- Services in this stack are independent of the network stack and can be restarted separately
