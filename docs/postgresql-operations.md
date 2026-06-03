# PostgreSQL Streaming Replication + PgBouncer Operations Runbook

## Architecture Overview

- **PostgreSQL 17 streaming replication (3 nodes)**
  - postgresql0: `10.151.14.220` (CT `280` on `hela`)
  - postgresql1: `10.151.14.221` (CT `281` on `loki`)
  - postgresql2: `10.151.14.222` (CT `282` on `thor`)
- Data directory: `/var/lib/postgresql/17/main`
- Config directory: `/etc/postgresql/17/main`
- Primary is **dynamic**. Detect at runtime with `pg_is_in_recovery()`.
- **VIP**: `10.151.14.225` managed by Keepalived (`virtual_router_id=153`)
  - Notify script: `/usr/local/bin/keepalived-postgresql-notify.sh`
  - Keepalived health check: `/usr/local/bin/check-postgresql.sh`
- **PgBouncer** runs on every node on port `6432`
  - Config: `/etc/pgbouncer/pgbouncer.ini`
  - User list: `/etc/pgbouncer/userlist.txt`
- Standbys use `primary_conninfo` in `postgresql.auto.conf` and replicate via VIP `10.151.14.225:5432` with user `replicator`
- Application DBs/users:
  - `radarr-main`, `radarr-log` / `radarr`
  - `sonarr-main`, `sonarr-log` / `sonarr`
  - `monica` / `monica`
  - `openwebui` / `openwebui`
  - `paperless` / `paperless`
- Backups run nightly at `03:00` on **current primary only**:
  - Script: `/usr/local/bin/postgresql-backup.sh`
  - Local dir: `/var/backups/postgresql`
  - Azure Blob: account `banceyprodstor`, container `postgresql-backups`
  - Retention: `14` days
  - Log: `/var/log/postgresql-backup.log`

## Node Inventory

| Name | Hostname/DNS | IP | CT ID | Proxmox Host | Typical Role |
|---|---|---|---:|---|---|
| postgresql0 | postgresql0 | 10.151.14.220 | 280 | hela | PostgreSQL + PgBouncer + Keepalived |
| postgresql1 | postgresql1 | 10.151.14.221 | 281 | loki | PostgreSQL + PgBouncer + Keepalived |
| postgresql2 | postgresql2 | 10.151.14.222 | 282 | thor | PostgreSQL + PgBouncer + Keepalived |

## Access Paths

- **Direct SSH** to Proxmox hosts:
  - `hela` (`10.151.14.12`), `loki` (`10.151.14.14`), `thor` (`10.151.14.13`)
- **Proxmox Web UI**:
  - `https://10.151.14.12:8006`, `https://10.151.14.14:8006`, `https://10.151.14.13:8006`
  - Open Datacenter -> node -> CT (`280`-`282`) -> use **Stop/Start/Reboot**

## Identifying the Current Primary

Check listener state:

```bash
pg_isready -h 10.151.14.220
pg_isready -h 10.151.14.221
pg_isready -h 10.151.14.222
```

Check recovery mode (`f` = primary, `t` = standby):

```bash
ssh root@10.151.14.220 "sudo -u postgres psql -U postgres -tAc \"SELECT pg_is_in_recovery();\""
ssh root@10.151.14.221 "sudo -u postgres psql -U postgres -tAc \"SELECT pg_is_in_recovery();\""
ssh root@10.151.14.222 "sudo -u postgres psql -U postgres -tAc \"SELECT pg_is_in_recovery();\""
```

One-liner for all nodes:

```bash
for ip in 10.151.14.220 10.151.14.221 10.151.14.222; do echo "=== $ip ==="; pg_isready -h "$ip"; ssh root@"$ip" "sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\""; done
```

## Service Management

### Service status checks

```bash
ssh root@10.151.14.220 "systemctl status postgresql pgbouncer keepalived"
ssh root@10.151.14.221 "systemctl status postgresql pgbouncer keepalived"
ssh root@10.151.14.222 "systemctl status postgresql pgbouncer keepalived"
```

### Restart PostgreSQL safely on a standby

`standby.signal` keeps the node in standby mode, so it will re-attach via streaming replication after restart.

```bash
ssh root@10.151.14.221 "systemctl restart postgresql"
ssh root@10.151.14.221 "ls /var/lib/postgresql/17/main/standby.signal"
```

### Restart PostgreSQL safely on the primary

1. Stop Keepalived on all nodes:

```bash
ssh root@10.151.14.220 "systemctl stop keepalived"
ssh root@10.151.14.221 "systemctl stop keepalived"
ssh root@10.151.14.222 "systemctl stop keepalived"
```

2. Restart PostgreSQL on the current primary (example shown for `10.151.14.220`):

```bash
ssh root@10.151.14.220 "systemctl restart postgresql"
```

3. Wait until ready:

```bash
pg_isready -h 10.151.14.220
```

4. Start Keepalived on all nodes:

```bash
ssh root@10.151.14.220 "systemctl start keepalived"
ssh root@10.151.14.221 "systemctl start keepalived"
ssh root@10.151.14.222 "systemctl start keepalived"
```

### Restart PgBouncer

```bash
ssh root@10.151.14.220 "systemctl restart pgbouncer"
ssh root@10.151.14.221 "systemctl restart pgbouncer"
ssh root@10.151.14.222 "systemctl restart pgbouncer"
```

### Restart PostgreSQL LXCs from Proxmox (`pct`)

```bash
ssh root@10.151.14.12 "pct restart 280"
ssh root@10.151.14.14 "pct restart 281"
ssh root@10.151.14.13 "pct restart 282"
```

> Ansible-managed remediation path:
>
> ```bash
> ansible-playbook -i ansible/hosts.yaml ansible/postgresql.yaml -l postgresql0,postgresql1,postgresql2
> ```

## Replication & Failover

### Check replication health (on primary)

```bash
ssh root@10.151.14.220 "sudo -u postgres psql -c \"SELECT * FROM pg_stat_replication;\""
ssh root@10.151.14.220 "sudo -u postgres psql -c \"SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;\""
```

Run on whichever node is currently primary.

### Planned failover (promote a standby)

1. Stop current primary gracefully.
2. Promote chosen standby.

Example promoting `postgresql1` (`10.151.14.221`):

```bash
ssh root@10.151.14.220 "systemctl stop postgresql"
ssh root@10.151.14.221 "sudo -u postgres psql -c \"SELECT pg_promote();\""
# or
ssh root@10.151.14.221 "sudo -u postgres pg_ctl promote -D /var/lib/postgresql/17/main"
```

3. Re-check `pg_is_in_recovery()` on all nodes.
4. Re-add old primary as standby if needed (see below).

### Promote standby after primary failure

Compare standby WAL positions:

```bash
ssh root@10.151.14.221 "sudo -u postgres psql -tAc \"SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();\""
ssh root@10.151.14.222 "sudo -u postgres psql -tAc \"SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();\""
```

Promote the most up-to-date standby:

```bash
ssh root@10.151.14.221 "sudo -u postgres psql -c \"SELECT pg_promote();\""
```

Verify promotion:

```bash
ssh root@10.151.14.221 "sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\""
```

Expected result: `f`.

Keepalived should then move VIP `10.151.14.225` to the promoted primary.

### Re-add a stale node as standby

```bash
ssh root@10.151.14.220 "systemctl stop postgresql"
ssh root@10.151.14.220 "rm -rf /var/lib/postgresql/17/main"
ssh root@10.151.14.220 "sudo -u postgres pg_basebackup -h 10.151.14.225 -U replicator -D /var/lib/postgresql/17/main -Fp -Xs -P -R"
ssh root@10.151.14.220 "ls /var/lib/postgresql/17/main/standby.signal"
ssh root@10.151.14.220 "systemctl start postgresql"
```

## Backup Operations

### Run backup manually

```bash
ssh root@10.151.14.220 "bash /usr/local/bin/postgresql-backup.sh"
```

### Watch backup logs

```bash
ssh root@10.151.14.220 "tail -f /var/log/postgresql-backup.log"
```

Backups run on the current primary only. If primary has changed, re-run playbook to re-pin cron:

```bash
ansible-playbook -i ansible/hosts.yaml ansible/postgresql.yaml -l postgresql0,postgresql1,postgresql2
```

## Troubleshooting

### Standby not replicating / connection refused

```bash
ssh root@10.151.14.221 "ls /var/lib/postgresql/17/main/standby.signal"
ssh root@10.151.14.221 "cat /var/lib/postgresql/17/main/postgresql.auto.conf"
ssh root@10.151.14.221 "journalctl -u postgresql -n 100"
ssh root@10.151.14.221 "psql -h 10.151.14.225 -U replicator -c \"\\conninfo\""
ssh root@10.151.14.220 "grep -n 'replication' /etc/postgresql/17/main/pg_hba.conf"
```

### Replication lag too high

```bash
ssh root@10.151.14.220 "sudo -u postgres psql -c \"SELECT * FROM pg_stat_replication;\""
```

Check standby disk I/O. If lag is unrecoverable, re-bootstrap with `pg_basebackup` (see re-add standby steps).

### VIP not on primary

```bash
ssh root@10.151.14.220 "systemctl status keepalived"
ssh root@10.151.14.221 "systemctl status keepalived"
ssh root@10.151.14.222 "systemctl status keepalived"
ssh root@10.151.14.220 "ip addr show | grep 10.151.14.225"
ssh root@10.151.14.221 "ip addr show | grep 10.151.14.225"
ssh root@10.151.14.222 "ip addr show | grep 10.151.14.225"
ssh root@10.151.14.220 "cat /usr/local/bin/keepalived-postgresql-notify.sh"
ssh root@10.151.14.220 "journalctl -u keepalived -n 50"
```

### PgBouncer connection issues

```bash
ssh root@10.151.14.220 "systemctl status pgbouncer"
ssh root@10.151.14.220 "tail -f /var/log/pgbouncer/pgbouncer.log"
ssh root@10.151.14.220 "psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer -c 'SHOW POOLS;'"
ssh root@10.151.14.220 "psql -h 127.0.0.1 -p 6432 -U pgbouncer pgbouncer -c 'SHOW CLIENTS;'"
ssh root@10.151.14.220 "cat /etc/pgbouncer/userlist.txt"
ssh root@10.151.14.220 "cat /etc/pgbouncer/pgbouncer.ini"
```

### "No PostgreSQL primary detected" (Ansible error)

This means all nodes reported standby or were not running.

```bash
pg_isready -h 10.151.14.220
pg_isready -h 10.151.14.221
pg_isready -h 10.151.14.222
ssh root@10.151.14.220 "sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\""
ssh root@10.151.14.221 "sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\""
ssh root@10.151.14.222 "sudo -u postgres psql -tAc \"SELECT pg_is_in_recovery();\""
```

If all are standbys, pick node with highest replay LSN and promote:

```bash
ssh root@10.151.14.221 "sudo -u postgres psql -tAc \"SELECT pg_last_wal_replay_lsn();\""
ssh root@10.151.14.222 "sudo -u postgres psql -tAc \"SELECT pg_last_wal_replay_lsn();\""
ssh root@10.151.14.221 "sudo -u postgres psql -c \"SELECT pg_promote();\""
```

Then re-run Ansible.

### Backup failures

```bash
ssh root@10.151.14.220 "cat /var/log/postgresql-backup.log"
ssh root@10.151.14.220 "which azcopy"
ssh root@10.151.14.220 "azcopy --version"
```

If primary changed since last run, re-run:

```bash
ansible-playbook -i ansible/hosts.yaml ansible/postgresql.yaml -l postgresql0,postgresql1,postgresql2
```
