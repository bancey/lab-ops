# MariaDB Galera + ProxySQL Operations Runbook

## Architecture Overview

- **MariaDB 11.4 Galera cluster (3 nodes)**
  - mariadb0: `10.151.14.210` (CT `270` on `hela`)
  - mariadb1: `10.151.14.211` (CT `271` on `loki`)
  - mariadb2: `10.151.14.212` (CT `272` on `thor`)
- MariaDB data directory: `/var/lib/mysql`
- Galera config: `/etc/mysql/mariadb.conf.d/60-galera.cnf`
- **ProxySQL layer (3 nodes)**
  - proxysql0: `10.151.14.216` (CT `273` on `hela`)
  - proxysql1: `10.151.14.217` (CT `274` on `loki`)
  - proxysql2: `10.151.14.218` (CT `275` on `thor`)
- **VIP**: `10.151.14.219` (`sql.heimelska.co.uk`) managed by Keepalived on ProxySQL nodes
- ProxySQL routing is single-writer:
  - writer hostgroup `0`
  - reader hostgroup `1`
  - backup_writer hostgroup `2`
  - offline hostgroup `3`
  - query rules: `SELECT ... FOR UPDATE` -> HG `0`, `SELECT` -> HG `1`, everything else -> HG `0`
- Application DBs/users:
  - `bunkerweb` / `bunkerweb`
  - `home-assistant` / `homeassistant`
  - `panel` / `pelican`
- Special users: `galera_sst`, `proxysql_monitor`, `root`
- Backups run on **mariadb0 only** at `02:00`:
  - Script: `/usr/local/bin/mariadb-backup.sh`
  - Local dir: `/var/backups/mariadb`
  - Azure Blob: account `banceyprodstor`, container `mariadb-backups`
  - Retention: `14` days
  - Log: `/var/log/mariadb-backup.log`

## Node Inventory

| Name | Hostname/DNS | IP | CT ID | Proxmox Host | Role |
|---|---|---|---:|---|---|
| mariadb0 | mariadb0 | 10.151.14.210 | 270 | hela | Galera node, bootstrap node, backup node |
| mariadb1 | mariadb1 | 10.151.14.211 | 271 | loki | Galera node |
| mariadb2 | mariadb2 | 10.151.14.212 | 272 | thor | Galera node |
| proxysql0 | proxysql0 / sql.heimelska.co.uk (via VIP) | 10.151.14.216 | 273 | hela | ProxySQL + Keepalived |
| proxysql1 | proxysql1 / sql.heimelska.co.uk (via VIP) | 10.151.14.217 | 274 | loki | ProxySQL + Keepalived |
| proxysql2 | proxysql2 / sql.heimelska.co.uk (via VIP) | 10.151.14.218 | 275 | thor | ProxySQL + Keepalived |

## Access Paths

- **Direct SSH** to Proxmox hosts:
  - `hela` (`10.151.14.12`), `loki` (`10.151.14.14`), `thor` (`10.151.14.13`)
- **Proxmox Web UI**:
  - `https://10.151.14.12:8006`, `https://10.151.14.14:8006`, `https://10.151.14.13:8006`
  - Open Datacenter -> node -> CT (`270`-`275`) -> use **Stop/Start/Reboot**

## Service Management

### MariaDB service status (inside LXC)

```bash
ssh root@10.151.14.210 "systemctl status mariadb"
ssh root@10.151.14.211 "systemctl status mariadb"
ssh root@10.151.14.212 "systemctl status mariadb"
```

### Restart MariaDB on a single node

Inside the LXC:

```bash
ssh root@10.151.14.211 "systemctl restart mariadb"
```

From Proxmox host with `pct`:

```bash
ssh root@10.151.14.14 "pct restart 271"
# or explicit stop/start
ssh root@10.151.14.14 "pct stop 271 && pct start 271"
```

### Restart ProxySQL

```bash
ssh root@10.151.14.216 "systemctl restart proxysql"
ssh root@10.151.14.217 "systemctl restart proxysql"
ssh root@10.151.14.218 "systemctl restart proxysql"
```

### Restart Keepalived on ProxySQL nodes

```bash
ssh root@10.151.14.216 "systemctl restart keepalived"
ssh root@10.151.14.217 "systemctl restart keepalived"
ssh root@10.151.14.218 "systemctl restart keepalived"
```

> Ansible-managed services can also be remediated by re-running:
>
> ```bash
> ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml -l mariadb0,mariadb1,mariadb2
> ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml -l proxysql0,proxysql1,proxysql2
> ```

## Galera Cluster Operations

### Check cluster health

MariaDB root credentials are in `/root/.my.cnf`, so `mysql` works without extra args:

```bash
ssh root@10.151.14.210 "mysql -e \"SHOW STATUS LIKE 'wsrep_%';\""
```

Key values:

- `wsrep_cluster_size` should be `3`
- `wsrep_local_state_comment` should be `Synced`
- `wsrep_cluster_status` should be `Primary`

### Safe rolling restart (maintenance)

Restart one node at a time in this order: `mariadb1` -> `mariadb2` -> `mariadb0` (bootstrap node last).

```bash
ssh root@10.151.14.211 "systemctl restart mariadb"
ssh root@10.151.14.211 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_local_state_comment';\""

ssh root@10.151.14.212 "systemctl restart mariadb"
ssh root@10.151.14.212 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_local_state_comment';\""

ssh root@10.151.14.210 "systemctl restart mariadb"
ssh root@10.151.14.210 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_local_state_comment';\""
```

Only continue when the current node reports `Synced`.

### Full cluster restart / bootstrap (all nodes down)

> **This scenario is now handled automatically by the Ansible playbook.**
>
> Running `ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml -l mariadb0,mariadb1,mariadb2`
> detects that MariaDB is installed but the cluster has no primary component and performs the
> recovery bootstrap automatically.  No manual intervention is required unless the automated
> recovery itself fails (check task output for errors).
>
> **How the playbook detects and recovers:**
> 1. On `mariadb0` it checks `dpkg-query` (installed?), `systemctl is-active` (running?), and
>    `SHOW STATUS LIKE 'wsrep_cluster_status'` (Primary?).
> 2. If MariaDB is installed but the service is not active **or** the cluster is not Primary,
>    `galera_recover_full_outage` is set to `true`.
> 3. The playbook stops mariadb on all nodes (idempotent), runs `galera_new_cluster` on
>    `mariadb0` only, waits for the socket, starts mariadb on `mariadb1` / `mariadb2`, then
>    polls `wsrep_cluster_size` until it reaches 3 before continuing.
> 4. apt package tasks run **after** the cluster is healthy, so the dpkg post-install restart
>    succeeds and partially-configured packages are resolved automatically.
>
> **Override variables** (pass with `-e` if needed):
> - No manual override variables are required; detection is fully automatic.
> - To force a specific tag, use `--tags galera_recover` is not currently implemented; simply
>   re-run the full playbook.

For manual recovery steps, or if the automated path fails, use the commands below:

```bash
ssh root@10.151.14.210 "systemctl stop mariadb"
ssh root@10.151.14.211 "systemctl stop mariadb"
ssh root@10.151.14.212 "systemctl stop mariadb"

ssh root@10.151.14.210 "galera_new_cluster"
ssh root@10.151.14.211 "systemctl start mariadb"
ssh root@10.151.14.212 "systemctl start mariadb"

ssh root@10.151.14.210 "mysql -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
```

Expected cluster size: `3`.

### Check which backend ProxySQL is writing to

```bash
ssh root@10.151.14.216 "mysql -u admin -p -h 127.0.0.1 -P 6032 -e \"SELECT * FROM runtime_mysql_servers;\""
ssh root@10.151.14.216 "mysql -u admin -p -h 127.0.0.1 -P 6032 -e \"SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers ORDER BY hostgroup_id;\""
```

## Backup Operations

### Run backup manually

```bash
ssh root@10.151.14.210 "bash /usr/local/bin/mariadb-backup.sh"
```

### Watch backup logs

```bash
ssh root@10.151.14.210 "tail -f /var/log/mariadb-backup.log"
```

### List local backup files

```bash
ssh root@10.151.14.210 "find /var/backups/mariadb -type f -name '*.sql.gz' | sort"
```

Backups only run on `mariadb0` (CT `270`).

## Troubleshooting

### Node not joining cluster / stuck in SST

```bash
ssh root@10.151.14.211 "journalctl -u mariadb -n 100"
ssh root@10.151.14.211 "tail -n 100 /var/log/mysql/error.log"
ssh root@10.151.14.211 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_local_state_comment';\""
```

`wsrep_local_state_comment` meanings:

- `Joining`: joining cluster
- `Donor/Desynced`: donating state / temporarily desynced
- `Joined`: state transfer complete, catching up
- `Synced`: fully in cluster

Check Galera connectivity (ports `4567`, `4568`):

```bash
ssh root@10.151.14.210 "nc -zv 10.151.14.211 4567 && nc -zv 10.151.14.211 4568"
ssh root@10.151.14.210 "nc -zv 10.151.14.212 4567 && nc -zv 10.151.14.212 4568"
```

### Cluster lost quorum / non-Primary

Symptoms: `wsrep_cluster_status = non-Primary`, writes rejected.

1. Identify most current node:

```bash
ssh root@10.151.14.210 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_last_committed';\""
ssh root@10.151.14.211 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_last_committed';\""
ssh root@10.151.14.212 "mysql -Nse \"SHOW STATUS LIKE 'wsrep_last_committed';\""
```

2. On the most up-to-date node, force bootstrap of Primary Component:

```bash
ssh root@10.151.14.210 "mysql -e \"SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';\""
```

3. Start/rejoin other nodes.

### ProxySQL not routing traffic

```bash
ssh root@10.151.14.216 "systemctl status proxysql"
ssh root@10.151.14.216 "mysql -u admin -p -h 127.0.0.1 -P 6032 -e \"SELECT hostgroup_id, hostname, port, status FROM runtime_mysql_servers;\""
ssh root@10.151.14.216 "mysql -u admin -p -h 127.0.0.1 -P 6032 -e \"SELECT * FROM monitor.mysql_server_connect_log ORDER BY time_start_us DESC LIMIT 10;\""
ssh root@10.151.14.216 "tail -f /var/lib/proxysql/proxysql.log"
```

### VIP not responding / Keepalived issues

```bash
ssh root@10.151.14.216 "systemctl status keepalived"
ssh root@10.151.14.216 "ip addr show | grep 10.151.14.219"
ssh root@10.151.14.217 "ip addr show | grep 10.151.14.219"
ssh root@10.151.14.218 "ip addr show | grep 10.151.14.219"
ssh root@10.151.14.216 "journalctl -u keepalived -n 50"
ssh root@10.151.14.216 "cat /usr/local/bin/check-proxysql.sh"
```

### Backup failures

```bash
ssh root@10.151.14.210 "cat /var/log/mariadb-backup.log"
ssh root@10.151.14.210 "which azcopy"
ssh root@10.151.14.210 "azcopy --version"
```

Azure endpoint connectivity test:

```bash
ssh root@10.151.14.210 "curl -I https://banceyprodstor.blob.core.windows.net/mariadb-backups"
```

If backup automation drifts, re-run:

```bash
ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml -l mariadb0
```
