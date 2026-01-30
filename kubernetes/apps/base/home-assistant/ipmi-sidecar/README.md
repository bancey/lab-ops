# IPMI Sidecar

A lightweight HTTP API sidecar container for controlling servers via IPMI from Home Assistant.

## Overview

This sidecar runs alongside Home Assistant and provides a simple REST API for power management of SuperMicro servers (or any IPMI-compatible server) without requiring ipmitool to be installed in the Home Assistant container.

## Building the Image

```bash
# Use the build script (recommended)
./build.sh your-registry/username

# Or build manually
docker build -t your-registry/ipmi-sidecar:latest .

# Push to your registry
docker push your-registry/ipmi-sidecar:latest
```

## Environment Variables

The following environment variables are required:

- `API_KEY` - API key for authenticating requests (required)
- `BMC_HOST` - IP address or hostname of the BMC/IPMI interface (required)
- `BMC_USER` - IPMI username (required)
- `BMC_PASSWORD` - IPMI password (required)
- `BMC_CIPHER_SUITE` - IPMI cipher suite (optional, default: 3)

## API Endpoints

All endpoints (except `/health`) require authentication via the `X-API-Key` header.

### Health Check
```
GET /health
```

Returns service health status.

### Power Status
```
GET /power/status
```

Returns the current power state of the server.

Response:
```json
{
  "success": true,
  "power_state": "on",
  "raw_output": "Chassis Power is on"
}
```

### Power On
```
POST /power/on
```

Powers on the server.

### Power Off (Graceful)
```
POST /power/off
```

Performs a graceful shutdown of the server.

### Power Off (Force)
```
POST /power/force-off
```

Immediately powers off the server (hard shutdown).

### Power Cycle
```
POST /power/cycle
```

Power cycles the server.

### Power Reset
```
POST /power/reset
```

Resets the server.

## Testing Locally

### Using Docker Compose (recommended for testing)

```bash
# Update environment variables in docker-compose.yaml with your IPMI credentials
# Then start the service
docker-compose up

# In another terminal, test the API
./test-api.sh http://localhost:8080 test-api-key-change-me
```

### Manual Testing

```bash
# Set environment variables
export API_KEY="your-secret-key"
export BMC_HOST="192.168.1.100"
export BMC_USER="admin"
export BMC_PASSWORD="password"
export FLASK_ENV="development"

# Install dependencies
pip install -r requirements.txt

# Run the application
python app.py

# Test the API (in another terminal)
./test-api.sh http://localhost:8080 your-secret-key

# Or test manually with curl
curl -H "X-API-Key: your-secret-key" http://localhost:8080/power/status
```

## Security Notes

- Always use strong, unique API keys
- Ensure BMC credentials are stored securely (use Kubernetes secrets with SOPS encryption)
- The container runs as a non-root user (UID 1000)
- API key authentication is required for all power management endpoints
