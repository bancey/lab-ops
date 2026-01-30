# IPMI Sidecar for Home Assistant

This documentation describes how to use the IPMI sidecar service to control servers via IPMI from Home Assistant.

## Overview

The IPMI sidecar is a lightweight HTTP API service that runs alongside Home Assistant in Kubernetes. It provides a simple REST interface for controlling SuperMicro (or any IPMI-compatible) servers without requiring `ipmitool` to be installed in the Home Assistant container.

## Architecture

The sidecar is deployed as an additional container in the same pod as Home Assistant, allowing it to communicate over localhost without network exposure. The architecture includes:

- **IPMI Sidecar Container**: Runs Python Flask API with `ipmitool` for IPMI communication
- **Home Assistant**: Calls the sidecar's HTTP endpoints using `rest_command` or similar integrations
- **Kubernetes Secret**: Stores IPMI credentials and API key (SOPS-encrypted)

## Prerequisites

1. An IPMI-compatible server (e.g., SuperMicro) with BMC configured and accessible from the Kubernetes cluster
2. IPMI credentials (username, password, BMC IP address)
3. Access to build and push the Docker image to a container registry

## Building and Pushing the Docker Image

The IPMI sidecar source code is located in `kubernetes/apps/base/home-assistant/ipmi-sidecar/`.

```bash
# Navigate to the sidecar directory
cd kubernetes/apps/base/home-assistant/ipmi-sidecar

# Build the Docker image
docker build -t your-registry/ipmi-sidecar:latest .

# Push to your registry
docker push your-registry/ipmi-sidecar:latest
```

**Note**: Update the image repository in `kubernetes/apps/base/home-assistant/release.yaml` to match your registry:

```yaml
ipmi-sidecar:
  image:
    repository: your-registry/ipmi-sidecar  # Update this
    tag: latest
```

## Configuration

### Step 1: Configure IPMI Credentials

Edit the secret file with SOPS:

```bash
# If the secret is already encrypted, edit it:
sops kubernetes/apps/base/home-assistant/ipmi-sidecar-secret.sops.yaml

# If it's a new file, encrypt it after editing:
sops -e -i kubernetes/apps/base/home-assistant/ipmi-sidecar-secret.sops.yaml
```

Update the following values:

```yaml
stringData:
  API_KEY: "your-secure-random-api-key-here"       # Generate a strong random key
  BMC_HOST: "192.168.1.100"                        # Your BMC/IPMI IP address
  BMC_USER: "ADMIN"                                 # IPMI username
  BMC_PASSWORD: "your-ipmi-password"                # IPMI password
  BMC_CIPHER_SUITE: "3"                             # Usually 3 for modern systems
```

**Security Best Practices**:
- Use a strong, unique API key (e.g., generate with `openssl rand -hex 32`)
- Ensure IPMI credentials are stored only in the SOPS-encrypted secret
- Never commit unencrypted secrets to version control

### Step 2: Deploy the Changes

Once configured, commit and push your changes. Flux will automatically sync and deploy the updated configuration to your Kubernetes cluster.

```bash
git add kubernetes/apps/base/home-assistant/
git commit -m "Add IPMI sidecar for server power management"
git push
```

## Home Assistant Integration

### REST Commands

Add the following to your Home Assistant `configuration.yaml` or create a new file in the `packages/` directory:

```yaml
rest_command:
  # Power on the server
  server_power_on:
    url: http://localhost:8080/power/on
    method: POST
    headers:
      X-API-Key: "your-secure-random-api-key-here"
    
  # Graceful power off
  server_power_off:
    url: http://localhost:8080/power/off
    method: POST
    headers:
      X-API-Key: "your-secure-random-api-key-here"
    
  # Force power off
  server_power_force_off:
    url: http://localhost:8080/power/force-off
    method: POST
    headers:
      X-API-Key: "your-secure-random-api-key-here"
    
  # Power cycle
  server_power_cycle:
    url: http://localhost:8080/power/cycle
    method: POST
    headers:
      X-API-Key: "your-secure-random-api-key-here"
    
  # Reset
  server_power_reset:
    url: http://localhost:8080/power/reset
    method: POST
    headers:
      X-API-Key: "your-secure-random-api-key-here"
```

### RESTful Sensor for Power Status

Add a sensor to monitor the power state:

```yaml
sensor:
  - platform: rest
    name: "Server Power Status"
    resource: http://localhost:8080/power/status
    method: GET
    headers:
      X-API-Key: "your-secure-random-api-key-here"
    value_template: "{{ value_json.power_state }}"
    json_attributes:
      - raw_output
    scan_interval: 30  # Check every 30 seconds
```

### Switch Entity

Create a switch to control server power from the UI:

```yaml
switch:
  - platform: template
    switches:
      server_power:
        friendly_name: "Server Power"
        value_template: "{{ is_state('sensor.server_power_status', 'on') }}"
        turn_on:
          service: rest_command.server_power_on
        turn_off:
          service: rest_command.server_power_off
        icon_template: >-
          {% if is_state('sensor.server_power_status', 'on') %}
            mdi:server
          {% else %}
            mdi:server-off
          {% endif %}
```

### Automations

Example automation to power on the server at a specific time:

```yaml
automation:
  - alias: "Server Power On Morning"
    trigger:
      - platform: time
        at: "08:00:00"
    action:
      - service: rest_command.server_power_on
    
  - alias: "Server Power Off Night"
    trigger:
      - platform: time
        at: "22:00:00"
    action:
      - service: rest_command.server_power_off
    
  - alias: "Server Power Status Notification"
    trigger:
      - platform: state
        entity_id: sensor.server_power_status
    action:
      - service: notify.notify
        data:
          message: "Server power state changed to {{ states('sensor.server_power_status') }}"
```

### Lovelace Dashboard Card

Add a card to your dashboard:

```yaml
type: entities
title: Server Control
entities:
  - entity: switch.server_power
  - entity: sensor.server_power_status
  - type: button
    name: Force Power Off
    tap_action:
      action: call-service
      service: rest_command.server_power_force_off
    icon: mdi:power
  - type: button
    name: Power Cycle
    tap_action:
      action: call-service
      service: rest_command.server_power_cycle
    icon: mdi:restart
```

## API Endpoints

All endpoints (except `/health`) require the `X-API-Key` header for authentication.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check endpoint (no auth required) |
| `/power/status` | GET | Get current power state |
| `/power/on` | POST | Power on the server |
| `/power/off` | POST | Graceful shutdown |
| `/power/force-off` | POST | Force power off (hard shutdown) |
| `/power/cycle` | POST | Power cycle the server |
| `/power/reset` | POST | Reset the server |

### Example API Response

**GET /power/status**:
```json
{
  "success": true,
  "power_state": "on",
  "raw_output": "Chassis Power is on"
}
```

**POST /power/on**:
```json
{
  "success": true,
  "output": "Chassis Power Control: Up/On",
  "command": "power on"
}
```

## Troubleshooting

### Check Sidecar Logs

```bash
# Find the pod name
kubectl get pods -n home-assistant

# View IPMI sidecar logs
kubectl logs -n home-assistant <pod-name> -c ipmi-sidecar
```

### Test API Locally

From within the Home Assistant container:

```bash
# Check health
curl http://localhost:8080/health

# Check power status
curl -H "X-API-Key: your-api-key" http://localhost:8080/power/status
```

### Common Issues

1. **Authentication Errors (401)**
   - Verify the API key in the secret matches the one in Home Assistant configuration
   - Check that the secret is properly mounted as environment variables

2. **IPMI Command Failures**
   - Verify BMC host is reachable from the Kubernetes cluster
   - Check IPMI credentials are correct
   - Try different cipher suite values (typically 3, 17, or 0)
   - Ensure BMC firmware is up to date

3. **Connection Timeouts**
   - Verify network connectivity between Kubernetes and BMC
   - Check firewall rules allow IPMI traffic (UDP port 623)

4. **Sidecar Container Not Starting**
   - Check that the Docker image was built and pushed correctly
   - Verify the image repository and tag in `release.yaml`
   - Check pod events: `kubectl describe pod <pod-name> -n home-assistant`

## Security Considerations

- The IPMI sidecar container runs as a non-root user (UID 1000)
- API authentication is required via the `X-API-Key` header
- IPMI credentials are stored in a Kubernetes secret encrypted with SOPS
- The service is only exposed within the pod (localhost), not to the cluster network
- Consider using network policies to further restrict BMC access

## Maintenance

### Updating the Sidecar

To update the sidecar code:

1. Make changes to files in `kubernetes/apps/base/home-assistant/ipmi-sidecar/`
2. Rebuild and push the Docker image
3. Update the image tag in `release.yaml` (or trigger a restart if using `latest`)
4. Flux will automatically deploy the update

### Changing IPMI Credentials

```bash
# Edit the encrypted secret
sops kubernetes/apps/base/home-assistant/ipmi-sidecar-secret.sops.yaml

# Commit and push
git add kubernetes/apps/base/home-assistant/ipmi-sidecar-secret.sops.yaml
git commit -m "Update IPMI credentials"
git push

# Restart the pod to pick up new credentials
kubectl rollout restart statefulset/home-assistant -n home-assistant
```

## Additional Resources

- [ipmitool documentation](https://github.com/ipmitool/ipmitool)
- [Home Assistant REST Command](https://www.home-assistant.io/integrations/rest_command/)
- [Home Assistant RESTful Sensor](https://www.home-assistant.io/integrations/rest/)
- [SOPS Documentation](https://github.com/getsops/sops)
