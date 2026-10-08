# OpenZiti vs Twingate

Phase 4 of the OpenZiti evaluation ([#1537](https://github.com/bancey/lab-ops/issues/1537)): a
side-by-side comparison with the existing Twingate setup, and a go/no-go decision for this homelab.
How OpenZiti is built and operated here is in [openziti.md](openziti.md).

Written 8 October 2026. The controller PKI was bootstrapped on 27 September 2026, so this covers
about two weeks of running OpenZiti, on 2.0.6 throughout.

## Decision

| Question | Decision |
| --- | --- |
| OpenZiti in the homelab | **Go: replace Twingate.** The cutover is gated on the [prerequisites](#cutover-prerequisites) below, mainly a tested restore and pipeline access. |
| Enterprise multi-tenant Azure | Covered in a separate private write-up, since it describes a non-public environment. |

The main reasons for the homelab:

- **No inbound access to home.** This was the second goal from Phase 1. Twingate meets it for
  remote access too, but Twingate doesn't help with Home Assistant, which is still published through
  the `hass.heimelska.co.uk` Cloudflare record and a 443 port-forward on the home router. With
  OpenZiti, Home Assistant becomes one more dark service, and the VPS (needed anyway as the front
  door) is the only public surface.
- **Access follows Entra.** Dial policies take Entra group names, and the group attribute sync keeps
  identities in line with membership. Twingate group membership is maintained in Twingate itself.
  It isn't in this repo.
- **No dependency on a vendor's free tier.** Twingate is on the free plan, whose limits and pricing
  Twingate can change. The VPS costs £40 a year and is needed as the front door regardless.
- **The model is reviewable.** `terraform/environments/prod/openziti.yaml` is a plan-able diff in the
  same shape as the other components.

The main cost is that the lab now runs its own access control plane, on a single VPS. That's covered
under [Failure modes](#failure-modes-and-recovery).

## What exists today

| | Twingate | OpenZiti |
| --- | --- | --- |
| Control plane | SaaS (`bancetech` account) | Self-hosted controller on vps01 (OVH) |
| Configuration | `terraform/components/twingate`, `twingate:` blocks in `terraform/environments/prod/dns.yaml`, `twingate_*` in `prod.tfvars` | `ansible/openziti.yaml` (hosts, PKI, routers, signer), `terraform/components/openziti` + `terraform/environments/prod/openziti.yaml` (policies, services) |
| Data plane | 3 connectors: two in the RPi `rpi_network` swarm stack, one Helm release on tiny (`kubernetes/apps/base/twingate`) | Public router on vps01; private routers `openziti` (VM on loki) and `nebula` (RPi) |
| Published | 30 resources in `dns.yaml`, plus 3 in `prod.tfvars` (two k8s node CIDRs and `birds-gateway`) | 7 services: 4 Proxmox UIs, Traefik on tiny, PostgreSQL, MariaDB |
| Access groups | 8 (`all`, `pve`, `tiny_k8s`, `wanda_k8s`, `pelican`, `plex`, `birds`, `pterodactyl`); every resource is also in `all` | 2 Dial tiers (`home-admin`, `home-data`) mapped to Entra groups |
| Non-human access | Service accounts `AzureDevOps` (on 29 resources, used by the pipeline), `Pelican` and `Pterodactyl` | JWT identities in `group_vars/openziti_controller.yaml`; none in use yet |

Some of the Twingate config is no longer needed and shouldn't be migrated: the `birds` remote network,
its connector and `birds-gateway`, the `birds` group, and the `Pelican`/`Pterodactyl` service accounts
and groups. Those accounts let an Azure game-server VM reach the panels at home, and that VM is gone.

## Comparison

### Setup and maintenance complexity

**Twingate** is a SaaS control plane plus connectors. All of it is Terraform and container images:
the component creates the network, groups, resources and service accounts, writes connector tokens to
Key Vault, and the connectors run as swarm services and a Helm release. There is no server, PKI,
firewall or backup to look after.

**OpenZiti** is considerably more to run:

- A hardened VPS (`vps-hardening.yaml`), with UFW and stateless OVH Edge Network Firewall rules that
  have to be set by hand, including the `established` rule without which the VPS can't reach the
  internet ([openziti.md](openziti.md#ovh-edge-firewall)).
- Controller bootstrap and PKI, a Let's Encrypt listener for join-by-URL with a certbot deploy hook,
  and router enrollment. All of this is in Ansible.
- The Entra ext-jwt-signer and auth policy (Ansible, since the Terraform provider lacks the enrollment
  fields), and the network model (Terraform).
- A group attribute sync script and a pipeline that runs it every 15 minutes, because the controller
  only applies the groups claim at enrollment.
- A nightly encrypted backup.

It works, and once built it's mostly hands-off. But there are three tools (Ansible, Terraform, the sync
script) and a manual OVH step where Twingate needs one Terraform component. Getting here took three
phases of work, and several of the problems hit along the way (the stateless edge firewall,
`bootstrap.bash` mangling passwords, the CA trust problem behind the public join URL) were
self-hosting problems that Twingate users never see.

**Verdict:** Twingate is simpler. Most of OpenZiti's complexity is a one-off build cost that has
already been paid. What's left is upkeep, covered under [Ongoing maintenance](#ongoing-maintenance).

### RBAC granularity in practice

**Twingate** grants access per resource (an address plus allowed ports) to groups and service
accounts. The model allows fine-grained access, but in practice every resource is in `all`, so anyone
in `all` reaches everything. The narrower groups only matter for users who aren't in `all`. Group
membership lives in Twingate, not in this repo or in Entra.

**OpenZiti** grants access per service (one intercept address and port, plus a host target) through
Dial policies on role attributes. Here:

- A service carries `#home-services`, which binds it to the home routers, and one access tier.
- Each tier's Dial policy names Entra groups in `openziti.yaml`, which the component resolves to the
  `#<object-id>` attributes that identities carry.
- The groups claim sets attributes at enrollment, and the sync script corrects them every 15 minutes
  after that. **Removing a user from a group takes up to 15 minutes to revoke access.**
- `ziti edge policy-advisor` explains why an identity can or can't dial a service. Twingate has
  nothing equivalent in the CLI.

Phase 3 tested this split (`lab-admins` vs `lab-developers`), and it works. It's finer than Twingate
in practice because each service is opted in explicitly. There is no `all`.

**Verdict:** OpenZiti is better here, and it's driven from Entra. The 15-minute revocation delay is
the weak spot. Twingate applies membership changes immediately, but here those changes are made by
hand in Twingate.

### End-user enrollment and login

**Twingate:** install the client, enter the network name (`bancetech`) and sign in. The client is
polished on every platform. Being logged in to the client and being connected are the same thing.

**OpenZiti:** install Ziti Desktop Edge or Ziti Mobile Edge, add an identity by URL
(`https://join.ziti.heimelska.co.uk`), choose the `entra` provider and sign in with Microsoft. Token
enrollment means nothing long-lived stays on the device, and revoking access in Entra applies at the
next connection ([why](openziti.md#token-enrollment-not-certificates)).

What's been tested:

| Client | Result |
| --- | --- |
| Ziti Desktop Edge, macOS | Works fine. |
| Ziti Mobile Edge, Android | Usable. Enrollment sometimes fails. That may be down to deleting and re-enrolling the profile repeatedly during testing, so it isn't yet known to be a client bug. Also produces harmless `tls: bad record MAC` errors on `:443` before each sign-in. |
| Ziti Desktop Edge, Windows | Not tested. Needs 2.5.2 or later for external providers. |
| iOS | Not tested. |

The main usability gap is the **"Add by URL" step**. Users have to type the join URL in, where
Twingate only needs a short network name. The ideal is a link the user clicks that opens the client
with the URL already filled in. Whether any Ziti client supports this (for example a URL scheme
handler) hasn't been checked. It's the most visible friction for anyone other than the lab owner, so
it's worth investigating before inviting other users.

Still open from Phase 2: what each client does when the Entra ID token expires (about an hour).

**Verdict:** Twingate is smoother, but OpenZiti is good enough for the people who use this lab. The
Entra sign-in itself works the same on both.

### Service publishing model

**Twingate:** one resource per address. The address can be a DNS name, an IP or a CIDR (the k8s node
subnets are `10.151.15.0/24` and `10.151.16.0/24`). Each resource has a TCP/UDP port allow-list, so
`thanos` exposes 22, 80, 443 and 8000 as a single entry. The resources are generated from `dns.yaml`,
next to the private DNS records, so adding a host and its remote access is one edit.

**OpenZiti:** one service per intercept/host pair, with an `intercept.v1` config (what clients dial)
and a `host.v1` config (where the home router sends it). Real hostnames are intercepted, so TLS and
OIDC redirect URIs keep working. Services are kept separately in `openziti.yaml`.

Moving to OpenZiti brings these differences:

- **One port per service.** As written, `terraform/components/openziti/services.tf` gives each service
  a single port. The 20 Twingate resources with SSH, and the hosts with 3–4 ports, would need one
  service per port, or a component change: a `ports` list on the intercept, with `forwardPort` and
  `allowedPortRanges` on `host.v1`.
- **No CIDR resources yet.** `intercept.v1` accepts CIDRs, but the component hasn't been used with
  them. The k8s subnet resources (SSH and 6443 for the pipeline) need this, or one service per node.
- **Two places to edit.** A host's DNS record (`dns.yaml`) and its remote access (`openziti.yaml`)
  are no longer in one file. One option is to generate Ziti services from a `ziti:` block in
  `dns.yaml`, the same way `twingate:` blocks work today.

**Verdict:** The models are equivalent for web UIs. Twingate is more concise for multi-port hosts and
subnets. That's a one-off component change, not a reason to stay.

### Failure modes and recovery

| Failure | Twingate | OpenZiti |
| --- | --- | --- |
| Control plane down | Twingate's SaaS; outside our control and rare | **vps01 is a single point of failure.** It runs the controller and the only public router. If it's down, there's no remote access, and new sessions can't authenticate even on the LAN, because the private routers' edge listeners still need the controller. |
| One home node down | 2 swarm connectors + 1 on tiny | 2 private routers (`openziti` on loki, `nebula`); losing one was tested in Phase 1 |
| Control-plane state lost | n/a | Nightly age-encrypted backup to `banceyprodstor/openziti-backups`. Restore runbook in [openziti.md](openziti.md#restore-untested-runbook-verify-before-relying-on-it) is **untested** |
| IdP (Entra) down | Sign-in fails | Sign-in fails. With token enrollment, existing sessions may end when their token expires (untested, see [enrollment](#end-user-enrollment-and-login)). |
| Vendor changes terms | Free plan could change or go | n/a (open source); NetFoundry stays an option |

Observed so far:

- vps01 has been up since 1 October 2026 without a controller or router restart (`NRestarts=0`). The
  home routers have run without restarts since they were last restarted on 6 October.
- Backups run nightly at 02:30 and upload successfully. Each archive is about 70 KB, so storage cost
  is negligible.
- **Restore time is unknown.** The runbook hasn't been run, so there's no measured recovery time.
  That has to change before cutover, because after cutover a lost VPS also means losing the
  pipeline's access to home (see [prerequisites](#cutover-prerequisites)).

Ways to reduce the single point of failure, roughly from cheapest to most costly:

1. Test the restore and measure it. A known recovery time of about an hour may be acceptable for a
   homelab.
2. Keep an out-of-band path home that doesn't depend on Ziti. For example, a break-glass route that
   doesn't reopen inbound ports, or physical access.
3. Add a second controller and public router on another cheap VPS, as a 3-node raft cluster or with
   2 nodes plus a witness. This is the right model for production use. It's probably overkill
   here.

### Ongoing maintenance

| Item | Status |
| --- | --- |
| OpenZiti package upgrades | `openziti_version` is `""` (unpinned), so whatever is current at install time is used, and the apt repo isn't covered by unattended-upgrades. All hosts are on **2.0.6**, matching the CLI pin in `infra-pipeline.yaml` and `ziti-sync-pipeline.yaml`. Pin `openziti_version: 2.0.6` and let Renovate bump all three together, so a new router can't join on a different version than the controller. |
| Controller leaf certs | `server.cert`/`client.cert` are valid for one year and already expire on **7 October 2027**, later than the 27 September 2027 that bootstrap would give. That's consistent with `ziti-controller-cert-renewal.timer` having already renewed them once. |
| Router certs | Extended on every start (`ZITI_ARGS=--extend`). A router that runs for over a year without a restart is the one case to watch. |
| Root and intermediate CA | Both expire on **27 September 2036** (10 years). Nothing to do for now. Add a reminder for 2035, because rotating the root means re-enrolling every router. |
| Let's Encrypt (join URL) | `certbot.timer` with the deploy hook restarting the controller. Automatic. |
| VPS patching, reboots | unattended-upgrades via `harden-ubuntu`. A reboot is a short full outage (see the single point of failure above). |
| OVH edge firewall | Manual rules, plus the temporary SSH rule #18 that the pipeline adds and removes. Changes are rare. |
| Group sync | Runs 96 times a day on Microsoft-hosted agents. Watch agent minutes. Drop the sync if OpenZiti adds claim refresh on authentication. |
| Twingate | Connector image updates via Renovate, connector token rotation, and the AzureDevOps service account key (rotated weekly by Terraform). |

**Verdict:** OpenZiti needs more upkeep, but nothing scheduled more often than yearly, and pinning
the version removes the main risk.

### Cost

| | Annual cost |
| --- | --- |
| Twingate | £0 on the free plan, which Twingate can change |
| OpenZiti | £40 for the OVH VPS. The VPS is also the planned front door for other ingress, so the cost of OpenZiti itself is close to £0. |
| Shared | Azure DevOps agent minutes (Twingate connect steps, and the Ziti sync's 96 runs a day) and backup storage (negligible) |

Both are effectively free. With OpenZiti the price is fixed and under our control. With Twingate it
depends on a vendor's free tier.

## Cutover prerequisites

The cutover is a separate issue. It should cover:

1. **Test the controller restore** end to end from a nightly backup, and record how long it takes in
   [openziti.md](openziti.md#backup-and-restore). Remove "untested" from the runbook heading.
2. **Pipeline access.** Give the Azure DevOps agent a Ziti identity: for example, run
   `ziti-edge-tunnel` on the agent with a JWT identity, or with an ext-JWT signer for the pipeline's
   workload identity. Use it to replace `twingate-connect`, `check-hosts-online` and the `AzureDevOps`
   service account. The pipeline uses it for SSH on 20 hosts, the AdGuard API (`prod_dns`) and the
   k8s APIs on 6443. The `openziti_ansible` stage has to keep working when Ziti is down, which it
   does today through OVH rule #18 and SSH.
3. **Extend the component for multi-port and CIDR services** (see
   [Service publishing](#service-publishing-model)), and decide whether services are generated from
   `dns.yaml`.
4. **Move the remaining resources** into `openziti.yaml`: the *arr apps, `dl`, `smokeping`,
   `tiny-pve`/`wanda-pve`/`wanda-mgmt`, `plex`, `matter`, `pelican`/`wings-thor`, SSH to the database
   and RPi hosts, and the k8s subnets. Add tiers as needed for `lab-users`, `lab-media` and
   `lab-infra`.
5. **Remove public ingress to home.** Delete the `hass.heimelska.co.uk` Cloudflare record from
   `prod.tfvars`, close the router's 443 port-forward, publish Home Assistant as a Ziti service, and
   check the Android companion app works through Ziti Mobile Edge.
6. **Pin `openziti_version`.**
7. **Remove Twingate:** `terraform/components/twingate` and the `prod_twingate` stage, the `twingate:`
   blocks in `dns.yaml` and `twingate_*` in `prod.tfvars`, the connectors in
   `stacks/network.stack.yml.j2` and `rpi-ha.yaml`, `kubernetes/apps/base/twingate` and its Helm
   repository, the Glance link, the Key Vault secrets, and the Twingate references in
   `docs/sso-operations.md`, `docs/migration/` and `CLAUDE.md`. The unused `birds`, `Pelican` and
   `Pterodactyl` entries can go before any of the other steps.

Before inviting anyone other than the lab owner, also look into a one-click join link (see
[enrollment](#end-user-enrollment-and-login)).
