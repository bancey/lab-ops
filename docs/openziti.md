# OpenZiti

OpenZiti is replacing Twingate for remote access. The long-term aim is to have no inbound
ports open on the home network at all, with the OVH VPS as the only internet-facing entry
point. Tracked in [#1534](https://github.com/bancey/lab-ops/issues/1534).

## Topology

```
 Ziti client (laptop/phone)
        │  tls :1280 (API)  tls :3022 (edge)
        ▼
 ┌─────────────────────────────── vps01 (OVH) ─┐
 │ ziti-controller   ziti.heimelska.co.uk:1280  │
 │ ziti-router       ziti.heimelska.co.uk:3022  │  public router, mode none
 └──────────────────────────────▲───────────────┘
                                │ router links, dialled *outbound* from home
             ┌──────────────────┴──────────────────┐
   openziti VM (loki, 10.151.14.230)       nebula (RPi, 10.151.14.7)
   private router, mode host               private router, mode host
             └────────── host.v1 ──────────────────┘
                        home services (e.g. wanda:8006)
```

- **Controller** runs on the VPS so it's reachable from anywhere without inbound access
  to home. It's a single-node cluster (`ZITI_BOOTSTRAP_CLUSTER=true`) with its own PKI
  under `/var/lib/ziti-controller/pki`. The leaf certs are renewed monthly by
  `ziti-controller-cert-renewal.timer`.
- **Public router** (`vps01`) is not tunneler-enabled. It only carries traffic:
  clients connect to it, and the home routers dial their links into it on the same port.
- **Private routers** (`openziti`, `nebula`) are generated with `--private`, so they
  have no link listener. They are tunneler-enabled in `host` mode and host the
  services. Having two of them gives each service two terminators, so losing either
  host (or all of loki/the RPi swarm) doesn't take it down.
- **Nothing at home accepts inbound traffic.** Clients on the LAN can still use the
  private routers' edge listeners (`<host>.heimelska.co.uk:3022`) directly.

## Code map

| What | Where |
| --- | --- |
| Playbook | `ansible/openziti.yaml` |
| Role (install/controller/enroll/router/objects) | `ansible/roles/openziti/` |
| Hosts & groups | `terraform/components/inventory/hosts.yaml.tpl`: `openziti_controller`, `openziti_public_routers`, `openziti_private_routers`, `openziti_routers` |
| Services & client identities | `ansible/group_vars/openziti_controller.yaml` |
| VPS UFW ports | `ansible/group_vars/cloud.yaml` (applied by `vps-hardening.yaml`) |
| Private router VM | `virtual_machines.openziti` in `terraform/environments/prod/prod.tfvars` |
| Public DNS `ziti.heimelska.co.uk` → VPS | `cloudflare_records` in `prod.tfvars` (must stay unproxied) |
| Private DNS/Twingate for the VM | `openziti.heimelska.co.uk` in `terraform/environments/prod/dns.yaml` |
| Pipeline | `openziti_ansible` stage in `infra-pipeline.yaml` |

## Deployment flow

The `openziti_ansible` stage runs after `vps_hardening_ansible`, `prod_dns` and
`tiny_virtual_machines`. It reaches the VPS through the temporary OVH rule #18 and
the home hosts through Twingate. The playbook has four plays:

1. **Install** the packages (`openziti-controller` and/or `openziti-router`) from the
   OpenZiti apt repo. Each router records whether it already has an identity
   (`/var/lib/ziti-router/router.cert`).
2. **Controller**: on first run, `/opt/openziti/etc/controller/bootstrap.bash` runs
   non-interactively (PKI, config, database, default admin). The play then logs the CLI
   in over loopback and creates edge routers in the controller for any router
   without an identity. If the router already exists in the controller, it's
   re-enrolled instead. The one-time JWTs are passed to the next play in memory.
3. **Routers**: `/opt/openziti/etc/router/bootstrap.bash` generates the config and
   enrolls using that JWT. Already-enrolled routers are left alone.
4. **Objects**: creates the edge-router/service-edge-router/service policies, tags the
   router tunneler identities with their role attributes, and creates the services
   and client identities from group vars.

Re-runs are idempotent. Bootstrap happens once; after that, `config.yml` on each host is
the source of truth. Objects are only **created** if missing and never updated. To
change one, delete it (`ziti edge delete ...`) and re-run the playbook.

The pipeline runs Ansible in check mode on PRs. Everything that talks to the
controller API is skipped in check mode, so a PR run only previews package and file
changes.

### Role-attribute model

| Attribute | On | Used by |
| --- | --- | --- |
| `#public-routers` | vps01 router | (informational) |
| `#home-routers` | home routers + their tunneler identities | Bind policy `home-routers-bind-home-services` |
| `#home-services` | services | Bind + Dial policies |
| `#users` | client identities | Dial policy `users-dial-home-services` |

Every identity may use every router, and every service may traverse every router
(`#all` edge-router and service-edge-router policies).

## One-time manual setup

### Key Vault secrets (`bancey-vault`)

- `OpenZiti-Admin-Username`, e.g. `admin`
- `OpenZiti-Admin-Password`: at least 16 characters from `A-Z a-z 0-9 ! @ # % ^ _ + ~ . = -`.
  `bootstrap.bash` mangles other characters, so the playbook asserts this.

The password is only used to create the default admin at bootstrap and to log the CLI
in. Rotating it in Key Vault alone does **not** change it in the controller. Run
`ziti edge update authenticator updb -s` first, then update Key Vault.

### OVH edge firewall

UFW on the VPS is opened for 1280/tcp and 3022/tcp by `vps-hardening.yaml`, but the
OVH Edge Network Firewall in front of it also needs permanent permit rules. Add them
(OVH console, or `ovhcloud ip firewall rule create`) **before** any deny-all rule and
not at sequence 18, which the pipeline reserves:

| Action | Protocol | Source | Dest. port | Option |
| --- | --- | --- | --- | --- |
| permit | tcp | any | | established |
| permit | tcp | any | 1280 | |
| permit | tcp | any | 3022 | |

Without the port rules, home routers can't enroll and clients can't connect. The
pipeline's own SSH rule doesn't cover them.

The edge firewall is stateless. Without the `established` rule, replies to
connections the VPS opens itself are dropped, so HTTPS to anything outside OVH times
out. Examples are the OpenZiti apt repo and key, or `curl https://get.openziti.io` on
the VPS. The Ubuntu mirror still works because it's inside OVH's network, which hides
the problem until something else needs the internet. OVH recommends putting this rule
first (sequence 0).

## Enrolling a client

Add the identity to `openziti_identities` in `ansible/group_vars/openziti_controller.yaml`
and let the pipeline run. Then fetch the JWT and delete it from the VPS:

```bash
ssh ubuntu@vps01.heimelska.co.uk sudo cat /opt/openziti/artifacts/phase1-test-user.jwt > phase1-test-user.jwt
ssh ubuntu@vps01.heimelska.co.uk sudo rm /opt/openziti/artifacts/phase1-test-user.jwt
```

Import it into Ziti Desktop Edge (or `ziti-edge-tunnel add --jwt ...`). JWTs expire
after 3 hours by default (the controller's `enrollment` duration). To reissue one:

```bash
sudo ziti edge delete identity phase1-test-user   # on the VPS, then re-run the pipeline
```

## Adding a service

Append to `openziti_services` in `ansible/group_vars/openziti_controller.yaml`:

```yaml
  - name: grafana
    role_attributes: [home-services]
    intercept_addresses: [grafana.ziti]   # what clients dial
    port: 443
    host_address: 10.151.16.200           # where the home routers send it
    # host_port: 8443                     # if it differs from port
```

## Validation

1. `ssh ubuntu@vps01.heimelska.co.uk sudo ziti edge list edge-routers`: all three
   routers online (`ONLINE: true`).
2. `sudo ziti edge list terminators` shows `wanda-pve` with a terminator from
   both `openziti` and `nebula`.
3. With the client enrolled, `https://wanda-pve.ziti:8006` loads (cert warning expected:
   the PVE cert isn't issued for that name).
4. Stop `ziti-router` on one home router; the service keeps working through the
   other.
5. From outside the LAN with the tunneller off, nothing new at home is reachable. The
   only new public surface is 1280/3022 on the VPS.

## Troubleshooting

```bash
sudo journalctl -u ziti-controller -f        # VPS
sudo journalctl -u ziti-router -f            # any router
sudo ziti edge policy-advisor services wanda-pve -q   # why can't X dial/bind Y?
```

If bootstrap fails, the scripts print the location of an output log and a temporary
answers file. These are under `/tmp` and can hold the admin password or enrollment
token, so delete them after debugging. To re-enroll a router, delete
`/var/lib/ziti-router/router.cert` on it and re-run the pipeline.

## Backup and restore

A nightly root cron job on the VPS (`/usr/local/bin/openziti-backup.sh`, 02:30,
logs to `/var/log/openziti-backup.log`) does the following:
- takes a consistent snapshot of the controller database through the running
  controller (`ziti agent controller snapshot-db`)
- tars the snapshot with `config.yml` and `pki/`
- encrypts the tarball with age, to the repo's SOPS recipient
- uploads it with azcopy to `banceyprodstor/openziti-backups`

Local copies are kept for 14 days in `/var/backups/openziti`. Retention in the storage
account is up to its lifecycle policy.

`pki/` holds the root and intermediate CA private keys. That's why the archive is
encrypted, and why a restore needs the `Flux-Age-Key` secret from Key Vault.

**One-time setup:**
- Create the `openziti-backups` container in `banceyprodstor`.
- Create a container-scoped SAS token with create and write permissions, and store it
  in Key Vault as `OpenZiti-Backup-SAS-Token`, as for the database backups. Store only
  the token query string (`sv=...&sig=...`), not the container URL. The script adds the
  URL itself.
- The pipeline fails if the secret is missing. To run without backups, set
  `openziti_backup_enabled: false` in `group_vars/openziti_controller.yaml` and remove
  the secret from the `openziti_ansible` stage in `infra-pipeline.yaml`.

Test the job by hand:

```bash
sudo /usr/local/bin/openziti-backup.sh && sudo ls -l /var/backups/openziti
```

### Restore (untested runbook, verify before relying on it)

Restoring the existing PKI means routers and enrolled clients keep trusting the
controller, so nothing needs re-enrolling. The controller address
(`ziti.heimelska.co.uk`) must stay the same.

1. Provision and harden the replacement VPS (`vps-hardening.yaml`), and point
   `ziti.heimelska.co.uk` at it.
2. Decrypt the archive on a machine that has the age key, and copy it to the VPS:
   ```bash
   az keyvault secret download --vault-name bancey-vault --name Flux-Age-Key --file key.txt
   age -d -i key.txt openziti-controller_<stamp>.tar.gz.age > restore.tar.gz && rm key.txt
   ```
3. On the VPS, install the packages but don't bootstrap:
   ```bash
   sudo apt install openziti-controller openziti-router
   ```
   Then unpack the archive into `/var/lib/ziti-controller` (`config.yml`, `pki/`,
   `ctrl.db`) and `chown -R ziti-controller:ziti-controller` it.
4. Start the controller, then initialise its raft cluster from the snapshot:
   ```bash
   sudo systemctl start ziti-controller
   sudo ziti agent cluster init-from-db --pid "$(systemctl show -p MainPID --value ziti-controller)" /var/lib/ziti-controller/ctrl.db
   ```
5. Run the pipeline. Controller bootstrap is skipped because `config.yml` exists.
   The VPS router has no identity locally, so the playbook re-enrolls it.
   `nebula` and `openziti` reconnect on their own.

## Teardown

Evaluation only. Everything can be rebuilt from scratch:

```bash
# VPS
sudo systemctl disable --now ziti-router ziti-controller ziti-controller-cert-renewal.timer
sudo crontab -l | grep -v openziti-backup | sudo crontab -   # nightly backup job
sudo rm -f /usr/local/bin/openziti-backup.sh
sudo apt purge -y openziti-controller openziti-router openziti
sudo rm -rf /var/lib/ziti-controller /var/lib/ziti-router /opt/openziti /root/.config/ziti

# nebula
sudo systemctl disable --now ziti-router
sudo apt purge -y openziti-router openziti && sudo rm -rf /var/lib/ziti-router
```

For the VM, remove `virtual_machines.openziti` from `prod.tfvars`. Then drop the hosts
from the `openziti_*` inventory groups, the DNS entries (`ziti.heimelska.co.uk` in
`cloudflare_records`, `openziti.heimelska.co.uk` in `dns.yaml`), the Ziti ports in
`ansible/group_vars/cloud.yaml`, and the OVH firewall rules.

## Next phases

- **Cutover**: move the remaining Twingate resources into `openziti_services`, then
  remove the `twingate` component, connectors and k8s release. Remove the public
  `hass.heimelska.co.uk` record and close the home router's 443 port-forward, so
  Home Assistant is only reachable over Ziti. The pipeline's own access to home hosts
  also needs moving off Twingate, e.g. a ziti-edge-tunnel step on the agent.
- Entra ID (OIDC) ext-jwt-signer for client auth, and group-based role attributes.
