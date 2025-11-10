# Migration Guide: Monolithic to Modular Docker Compose Stacks

This guide provides step-by-step instructions for migrating from the old monolithic Docker Compose deployment to the new modular stack architecture.

## Overview

The refactoring splits services into two independent stacks:
- **Network Stack** (`/opt/compose/network/`): AdGuard, Twingate, BunkerWeb
- **Monitoring Stack** (`/opt/compose/monitoring/`): Gatus, Alloy, cAdvisor, AdGuard Exporter

**Problem:** Running the new playbook directly will create duplicate containers with the same names and port conflicts, causing deployment failures.

## Migration Strategy

There are two recommended migration paths depending on your tolerance for downtime.

---

## Option 1: Clean Migration (Recommended - Short Downtime)

This approach stops all old services, cleans up, then deploys the new stacks. **Downtime: ~2-5 minutes per host**

### Step 1: Stop and Remove Old Stack

On each Raspberry Pi host, run:

```bash
# Navigate to the old compose directory
cd /opt/compose

# Stop all running containers
docker compose down

# Verify all containers are stopped
docker ps -a | grep -E "adguard|twingate|bunkerweb|gatus|alloy|cadvisor|adguard_exporter"

# Remove the old compose file
mv docker-compose.yaml docker-compose.yaml.backup
```

### Step 2: Deploy New Modular Stacks

Run the updated playbook to deploy both new stacks:

```bash
ansible-playbook ansible/rpi-ha.yaml
```

Or deploy stacks individually:

```bash
# Deploy network stack first (critical services)
ansible-playbook ansible/rpi-ha.yaml --tags network

# Then deploy monitoring stack
ansible-playbook ansible/rpi-ha.yaml --tags monitoring
```

### Step 3: Verify Deployment

On each host, verify services are running:

```bash
# Check network stack
docker compose -f /opt/compose/network/docker-compose.yaml ps

# Check monitoring stack
docker compose -f /opt/compose/monitoring/docker-compose.yaml ps

# Verify all services are healthy
docker ps --filter "status=running" | grep -E "adguard|twingate|bunkerweb|gatus|alloy|cadvisor|adguard_exporter"
```

### Step 4: Cleanup (Optional)

Once verified, remove the backup:

```bash
rm /opt/compose/docker-compose.yaml.backup
```

---

## Option 2: Gradual Migration (Minimal Downtime)

This approach migrates one stack at a time, keeping some services running. **Downtime: Service-specific, ~1-2 minutes per stack**

### Step 1: Prepare Migration Script

Create a migration script on each host:

```bash
cat > /tmp/migrate-stacks.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Starting Stack Migration ==="

# Stop only network stack services from old compose
cd /opt/compose
docker compose stop adguard twingate bunkerweb

# Remove only network stack containers
docker compose rm -f adguard twingate bunkerweb

# Backup old compose file
cp docker-compose.yaml docker-compose.yaml.backup

echo "Network stack stopped. Ready for new network stack deployment."
EOF

chmod +x /tmp/migrate-stacks.sh
```

### Step 2: Migrate Network Stack

Execute migration on each host:

```bash
# On the Ansible control node, use ad-hoc command
ansible rpi -b -m shell -a "/tmp/migrate-stacks.sh"

# Then deploy new network stack
ansible-playbook ansible/rpi-ha.yaml --tags network
```

### Step 3: Migrate Monitoring Stack

Create monitoring migration script:

```bash
cat > /tmp/migrate-monitoring.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Migrating Monitoring Stack ==="

cd /opt/compose
docker compose stop gatus alloy cadvisor adguard_exporter
docker compose rm -f gatus alloy cadvisor adguard_exporter

# Remove old compose file now that all services are migrated
rm -f docker-compose.yaml

echo "Monitoring stack stopped. Ready for new monitoring stack deployment."
EOF

chmod +x /tmp/migrate-monitoring.sh
```

Execute:

```bash
# Stop old monitoring services
ansible rpi -b -m shell -a "/tmp/migrate-monitoring.sh"

# Deploy new monitoring stack
ansible-playbook ansible/rpi-ha.yaml --tags monitoring
```

### Step 4: Verify and Cleanup

```bash
# Verify new stacks on each host
ansible rpi -b -m shell -a "docker compose -f /opt/compose/network/docker-compose.yaml ps"
ansible rpi -b -m shell -a "docker compose -f /opt/compose/monitoring/docker-compose.yaml ps"

# Cleanup migration scripts
ansible rpi -b -m shell -a "rm -f /tmp/migrate-*.sh /opt/compose/docker-compose.yaml.backup"
```

---

## Option 3: Fresh Deployment (Development/Testing)

For non-production environments, you can use a destructive approach:

```bash
# Stop and remove ALL containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Clean up old compose directory
rm -rf /opt/compose/*

# Deploy new stacks
ansible-playbook ansible/rpi-ha.yaml
```

**⚠️ WARNING:** This will stop ALL Docker containers, not just the affected services.

---

## Verification Checklist

After migration, verify the following on each host:

### Network Stack
- [ ] AdGuard Home accessible on port 53 (DNS) and 8000 (Web UI)
- [ ] Twingate connector running and connected
- [ ] BunkerWeb accessible on ports 80, 443, 5000
- [ ] Services defined in `/opt/compose/network/docker-compose.yaml`

### Monitoring Stack
- [ ] Gatus accessible on port 8080
- [ ] Alloy collecting metrics on port 12345
- [ ] cAdvisor accessible on port 8081
- [ ] AdGuard Exporter exporting metrics on port 9618
- [ ] Services defined in `/opt/compose/monitoring/docker-compose.yaml`

### General Checks
```bash
# All services should be running
docker ps | wc -l  # Should show 7 containers + header

# No old compose file should exist
ls -la /opt/compose/docker-compose.yaml  # Should not exist

# New stack files should exist
ls -la /opt/compose/network/docker-compose.yaml
ls -la /opt/compose/monitoring/docker-compose.yaml

# Check logs for errors
docker compose -f /opt/compose/network/docker-compose.yaml logs --tail=50
docker compose -f /opt/compose/monitoring/docker-compose.yaml logs --tail=50
```

---

## Troubleshooting

### Issue: Port conflicts after migration

**Symptom:** Services fail to start with "port already in use" errors

**Solution:**
```bash
# Find processes using the ports
sudo netstat -tulpn | grep -E ":53|:80|:443|:8000|:8080|:8081|:9618|:12345"

# If old containers are still running, force remove them
docker ps -a | grep -E "adguard|twingate|bunkerweb|gatus|alloy|cadvisor|adguard_exporter"
docker rm -f <container_id>
```

### Issue: Container name conflicts

**Symptom:** Error: "container name already in use"

**Solution:**
```bash
# List all containers (including stopped)
docker ps -a

# Remove conflicting containers
docker rm -f adguard twingate bunkerweb gatus alloy cadvisor adguard_exporter banceylab-connector
```

### Issue: Old compose file interfering

**Symptom:** Playbook trying to use old compose location

**Solution:**
```bash
# Backup and remove old file
sudo mv /opt/compose/docker-compose.yaml /opt/compose/docker-compose.yaml.old

# Verify removal
ls -la /opt/compose/
```

### Issue: Network connectivity problems after migration

**Symptom:** Services can't communicate or resolve DNS

**Solution:**
```bash
# Check Docker networks
docker network ls

# Verify services are on correct networks
docker compose -f /opt/compose/network/docker-compose.yaml ps
docker compose -f /opt/compose/monitoring/docker-compose.yaml ps

# Restart stacks if needed
docker compose -f /opt/compose/network/docker-compose.yaml restart
docker compose -f /opt/compose/monitoring/docker-compose.yaml restart
```

---

## Rollback Procedure

If you need to rollback to the old monolithic stack:

```bash
# Stop new stacks
docker compose -f /opt/compose/network/docker-compose.yaml down
docker compose -f /opt/compose/monitoring/docker-compose.yaml down

# Restore old compose file
mv /opt/compose/docker-compose.yaml.backup /opt/compose/docker-compose.yaml

# Start old stack
cd /opt/compose
docker compose up -d

# Verify
docker compose ps
```

---

## Post-Migration Benefits

After successful migration, you can:

1. **Update individual stacks** without affecting others
2. **Debug services** in isolation
3. **Scale stacks** independently
4. **Use tags** for selective deployment:
   ```bash
   # Deploy only network changes
   ansible-playbook ansible/rpi-ha.yaml --tags network
   
   # Deploy only monitoring changes
   ansible-playbook ansible/rpi-ha.yaml --tags monitoring
   ```

---

## Questions or Issues?

If you encounter problems during migration:

1. Check the troubleshooting section above
2. Review logs: `docker compose logs` in each stack directory
3. Verify network connectivity and DNS resolution
4. Ensure all required ports are free before deployment

For additional help, refer to:
- `ansible/README.md` - Architecture documentation
- `ansible/roles/rpi-network/README.md` - Network stack details
- `ansible/roles/rpi-monitoring/README.md` - Monitoring stack details
