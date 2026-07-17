# Raspberry Pi Swarm Operations Checklist

Use this checklist after bootstrap, upgrades, or rollback operations.

## 1. Cluster Health
- `docker node ls`
- `docker stack ls`
- `docker service ls`

Expected:
- Primary manager shows `Leader`.
- All three Raspberry Pi nodes show `Ready` and `Active`.
- `rpi_network` and `rpi_monitoring` stacks are present.

## 2. Placement and Pinning Validation

### Scanner + UPS remain pinned to gamora
- `ansible -i ansible/hosts.yaml gamora -m ansible.builtin.shell -a 'systemctl is-active nut-server scanbd scansnap-retry.timer'`
- `ansible -i ansible/hosts.yaml 'rpi:!gamora' -m ansible.builtin.shell -a 'systemctl is-active nut-server scanbd scansnap-retry.timer || true'`

Expected:
- Services active on `gamora`.
- Services absent/inactive on non-gamora nodes.

## 3. Swarm Service Placement Verification
- `docker service ps rpi_network_adguard --no-trunc`
- `docker service ps rpi_network_bunkerweb --no-trunc`
- `docker service ps rpi_monitoring_gatus --no-trunc`
- `docker service ps rpi_monitoring_alloy --no-trunc`

Expected:
- Service placement matches constraints and capacity expectations.

## 4. Update + Rollback Drill

### Example update
- `docker service update --image twinproduction/gatus:v5.36.0 rpi_monitoring_gatus`
- `docker service ps rpi_monitoring_gatus`

### Example rollback
- `docker service rollback rpi_monitoring_gatus`
- `docker service ps rpi_monitoring_gatus`

Expected:
- Update converges successfully.
- Rollback returns service to prior task definition/image.

## 5. Deploy from Git State
- `./scripts/validate-swarm-stack-templates.sh`
- `./scripts/deploy-rpi-swarm.sh --manager thanos`

Expected:
- Validation passes.
- Playbook converges with no destructive drift.

## 6. Troubleshooting Commands
- `docker service logs -f rpi_monitoring_gatus`
- `docker service logs -f rpi_network_adguard`
- `docker events --since 10m`
- `journalctl -u docker -n 200 --no-pager`
- `systemctl status keepalived --no-pager`

## 7. Keepalived and Swarm Posture Validation
- `ip addr show | grep 10.151.14.4`
- `systemctl status keepalived --no-pager`
- `docker node ls`

Expected:
- keepalived still controls edge VIP failover.
- Swarm controls service scheduling independently.
