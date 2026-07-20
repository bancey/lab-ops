# RPi Monitoring Role

This Ansible role manages the monitoring and observability Docker Swarm stack for Raspberry Pi hosts.

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

The rendered Docker Swarm stack file is deployed to:
```
/opt/stacks/monitoring.stack.yml
```

## Variables

Required variables (passed from playbook):
- `adguard_username`: Username for AdGuard Home API access
- `adguard_password`: Password for AdGuard Home API access
- `gatus_discord_webhook_url`: Discord webhook URL for Gatus alerts

Optional variables (with defaults):
- `gatus_config_template`: Gatus config template name (default: `gatus-config.yaml.j2` - uses template from role's `templates/` directory)
- `alloy_config_template`: Alloy config template name (default: `alloy-config.alloy.j2` - uses template from role's `templates/` directory)

To use custom configuration files, override these variables in your playbook:
```yaml
- role: rpi-monitoring
  vars:
    # Absolute paths or relative paths (starting with ./ or ../) are supported
    gatus_config_template: "/path/to/custom/gatus-config.yaml.j2"
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
docker service ls | grep rpi_monitoring

# Reconcile stack
docker stack deploy -c /opt/stacks/monitoring.stack.yml rpi_monitoring

# View logs
docker service logs -f rpi_monitoring_alloy

# Restart specific service
docker service update --force rpi_monitoring_alloy

# Remove stack
docker stack rm rpi_monitoring
```

## Dependencies

- Docker Engine with Swarm enabled
- Gatus configuration file
- Alloy configuration file

## Directory Structure

```
/opt/stacks/monitoring.stack.yml # Rendered stack manifest on manager
/opt/gatus/config/               # Gatus configuration
/opt/gatus/data/                 # Gatus data directory
/opt/alloy/config/               # Alloy configuration
```

## Notes

- AdGuard Exporter connects to the AdGuard Home service via the VIP (10.151.14.4:8000)
- Both Alloy and cAdvisor keep privileged host access settings from pre-swarm deployment.
- Services in this stack are independent of the network stack and can be updated separately.
