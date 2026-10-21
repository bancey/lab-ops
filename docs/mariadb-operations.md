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
  - Local dir: `/var/backups/mariadb` (staging only, `3` days retention)
  - Azure Blob: account `banceyprodstor`, container `mariadb-backups`, path `<db>/<db>_<host>_<timestamp>.sql.gz` (backups from Apr–Oct 2026 also sit under `mariadb/<db>/`)
  - Log: `/var/log/mariadb-backup.log` (rotated weekly)
  - Monitoring: the script reports to the Gatus external endpoint `backups/mariadb` on both Gatus instances; Gatus alerts to Discord on a failed run, or if no result arrives within 25h

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

> **This scenario is handled automatically by the Ansible playbook.**
>
> Run `ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml` against **all** Galera nodes
> (no `--limit`). It only bootstraps when no node is in a Primary component, and then bootstraps
> from the node with the newest data.

#### How the playbook detects and recovers

Every node reports whether `mariadb-server` is installed, whether the service is active and its `wsrep_cluster_status`. From those:

| Fact | Condition |
|---|---|
| `galera_primary_nodes` | Nodes that are active **and** `Primary` |
| `galera_bootstrap_required` | `galera_primary_nodes` is empty |
| `galera_recover_full_outage` | `galera_primary_nodes` is empty **and** MariaDB is installed on at least one node |

If **any** node is Primary, the cluster is healthy: nothing is stopped, and nodes that are down are just started so they rejoin via IST/SST. A single dead node, even `mariadb0`, never triggers a bootstrap. (Before October 2026 only `mariadb0` was checked, so a dead `mariadb0` stopped the healthy nodes and bootstrapped from its stale data.)

If no node is Primary but not every Galera node is in the play (e.g. `--limit`), the playbook fails rather than guess.

When `galera_recover_full_outage` is `true`, the recovery runs **before** the `apt` package tasks. `apt`'s `mariadb-server` post-install script restarts MariaDB, which fails while no primary component exists and leaves packages `partially configured`.

#### Automated recovery sequence

1. Stop `mariadb` on all nodes.
2. Run `mariadbd --wsrep-recover` on every node to get the last committed `uuid:seqno` from InnoDB (`grastate.dat` shows `seqno: -1` after an unclean stop, so it can't be trusted on its own).
3. Pick the node with the highest seqno as `galera_bootstrap_node`. The play stops for manual recovery if:
   - a node that may hold data returns no position. Only nodes that provably have no cluster history are skipped: MariaDB not installed, or a zeroed UUID (never joined, or wiped by an interrupted SST, as with mariadb0 in October 2026). The recovery log is kept at `/var/tmp/wsrep-recover.log` on each node;
   - nodes recover different cluster UUIDs, because seqnos can't be compared across histories;
   - no node has a usable position.
4. Set `safe_to_bootstrap: 1` on that node, `0` on the others, and run `galera_new_cluster` there.
5. Create/refresh users on the bootstrap node, start `mariadb` on the other nodes, and wait until `wsrep_cluster_size` equals the number of nodes.

User and database tasks always run once on `galera_admin_node`: the bootstrap node after an outage, otherwise `mariadb0` if it is Primary, or else the first Primary node.

#### Fresh install vs healthy cluster

- **Fresh install** (nothing installed anywhere): `apt` runs first, then `mariadb0` is bootstrapped and the others join.
- **Healthy cluster** (at least one node Primary): no bootstrap; services are ensured started and enabled.

For manual recovery steps, or if the automated path fails, use the commands below. Find the newest node first, and bootstrap from **that** node (shown here as mariadb1):

```bash
for ip in 10.151.14.210 10.151.14.211 10.151.14.212; do
  ssh root@$ip "systemctl stop mariadb; mariadbd --user=mysql --wsrep-recover --log-error=/tmp/wsrep-recover.log; grep 'Recovered position' /tmp/wsrep-recover.log"
done

ssh root@10.151.14.211 "sed -i 's/^safe_to_bootstrap:.*/safe_to_bootstrap: 1/' /var/lib/mysql/grastate.dat && galera_new_cluster"
ssh root@10.151.14.212 "systemctl start mariadb"
ssh root@10.151.14.210 "systemctl start mariadb"

ssh root@10.151.14.211 "mysql -e \"SHOW STATUS LIKE 'wsrep_cluster_size';\""
```

A node whose datadir is damaged (e.g. `ib_logfile0 was not found`, zeroed UUID in `grastate.dat`) won't start or rejoin. Once the cluster is Primary, empty its datadir so it takes a full SST: `systemctl stop mariadb; find /var/lib/mysql -mindepth 1 -delete; systemctl start mariadb`. The SST stages a full copy of the data (~24G as of Oct 2026), so check free disk first.

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

Gatus (`backups/mariadb`) alerts when a run fails or no result arrives within 25h. The log has one line per dump/upload and an `ERROR: backup failed: ...` summary naming the failed databases. The script exits early without dumping if mariadb0 isn't a `Synced` Galera member.

```bash
ssh root@10.151.14.210 "grep -E 'ERROR|WARN|completed' /var/log/mariadb-backup.log | tail"
ssh root@10.151.14.210 "df -h /"
ssh root@10.151.14.210 "which azcopy"
ssh root@10.151.14.210 "azcopy --version"
```

Azure endpoint connectivity test:

```bash
ssh root@10.151.14.210 "curl -I https://banceyprodstor.blob.core.windows.net/mariadb-backups"
```

If backup automation drifts, re-run:

```bash
ansible-playbook -i ansible/hosts.yaml ansible/mariadb.yaml
```

Don't `--limit` this to `mariadb0`: cluster health is judged from every node in the run.
