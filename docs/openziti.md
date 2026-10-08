# OpenZiti

OpenZiti is replacing Twingate for remote access. The long-term aim is to have no inbound
ports open on the home network at all, with the OVH VPS as the only internet-facing entry
point. Tracked in [#1534](https://github.com/bancey/lab-ops/issues/1534). The comparison with
Twingate and the go/no-go decision are in [openziti-vs-twingate.md](openziti-vs-twingate.md).

## Topology

```
 Ziti client (laptop/phone)
        │  tls :443 (join)  tls :1280 (API)  tls :3022 (edge)
        ▼
 ┌─────────────────────────────── vps01 (OVH) ─┐
 │ ziti-controller   join.ziti.heimelska.co.uk  │  :443, Let's Encrypt, client API only
 │                   ziti.heimelska.co.uk:1280  │  controller PKI
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
- **Public client API** (`join.ziti.heimelska.co.uk`, port 443) is a second controller
  listener for "join by URL". See [Public join URL](#public-join-url).
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
| Policies, services, RBAC (the network model) | `terraform/environments/prod/openziti.yaml`, applied by `terraform/components/openziti` |
| JWT client identities, Entra signer & auth policy | `ansible/group_vars/openziti_controller.yaml` |
| Entra app registration (`lab-openziti`) | `terraform/environments/prod/entra.yaml` |
| VPS UFW ports | `ansible/group_vars/cloud.yaml` (applied by `vps-hardening.yaml`) |
| Private router VM | `virtual_machines.openziti` in `terraform/environments/prod/prod.tfvars` |
| Public DNS `ziti.heimelska.co.uk`, `join.ziti.heimelska.co.uk` → VPS | `cloudflare_records` in `prod.tfvars` (must stay unproxied) |
| Public join URL (Let's Encrypt, 443 listener) | `ansible/roles/openziti/tasks/public_api.yaml` |
| Private DNS/Twingate for the VM | `openziti.heimelska.co.uk` in `terraform/environments/prod/dns.yaml` |
| Pipeline | `openziti_ansible` then `prod_openziti` stages in `infra-pipeline.yaml` |
| Entra group → identity attribute sync | `scripts/sync-ziti-identity-attributes.sh`, run by `terraform/components/openziti/sync.tf` and `ziti-sync-pipeline.yaml`. See [Group attribute sync](#group-attribute-sync) |

## Deployment flow

The `openziti_ansible` stage runs after `vps_hardening_ansible`, `prod_dns`,
`prod_entra` and `tiny_virtual_machines`. It reaches the VPS through the temporary OVH rule #18 and
the home hosts through Twingate. The playbook has four plays:

1. **Install** the packages (`openziti-controller` and/or `openziti-router`) from the
   OpenZiti apt repo. Each router records whether it already has an identity
   (`/var/lib/ziti-router/router.cert`).
2. **Controller**: on first run, `/opt/openziti/etc/controller/bootstrap.bash` runs
   non-interactively (PKI, config, database, default admin). On every run, the play
   ensures the public join listener and its Let's Encrypt certificate are in
   `config.yml`. It then logs the CLI in over loopback and creates edge routers in the
   controller for any router without an identity. If the router already exists in the controller, it's
   re-enrolled instead. The one-time JWTs are passed to the next play in memory.
3. **Routers**: `/opt/openziti/etc/router/bootstrap.bash` generates the config and
   enrolls using that JWT. Already-enrolled routers are left alone.
4. **Objects**: tags the router tunneler identities with their role attributes,
   reconciles the Entra ext-jwt-signer and auth policy, and creates JWT client
   identities from group vars.

Then the `prod_openziti` stage runs `terraform/components/openziti`, which owns the
network model: edge-router, service-edge-router and service policies, plus every
service with its `intercept.v1` and `host.v1` configs. It talks to the management API
on `ziti.heimelska.co.uk:1280`, so it needs neither Twingate nor the OVH SSH rule.
`terraform plan` on a PR shows the real diff, and removing an entry from
`openziti.yaml` removes the object from the controller.

Re-runs are idempotent. Bootstrap happens once; after that, `config.yml` on each host is
the source of truth. Ansible only creates JWT identities if missing; ext-jwt-signers
and auth policies are patched to match group vars on every run, so changing e.g. the
token type is just a PR.

Terraform doesn't own the signer because the provider (`netfoundry/ziti` 2.1.3) has no
enrollment fields on `ziti_external_jwt_signer` (`enroll_to_token`,
`enroll_attr_claims_selector`, `enroll_auth_policy`, ...). The auth policy stays with
it because it references the signer. Moving both is worth revisiting once the
provider gains those fields. Router tunneler identities are created by router
enrollment, so their tagging also stays in Ansible.

The pipeline runs Ansible in check mode on PRs. Everything that talks to the
controller API is skipped in check mode, so a PR run only previews package and file
changes. Terraform plans normally.

### Role-attribute model

Access follows the Entra groups from `terraform/environments/prod/entra.yaml`. The
signer has `enroll_attr_claims_selector: /groups`, so an identity auto-enrolled by Entra
gets the user's **group object IDs** as role attributes (the `groups` claim carries IDs,
not names). The Terraform component resolves group names to IDs with the `azuread`
provider, so `openziti.yaml` says `entra_groups: [lab-admins]` and the policy ends up
selecting `#<object-id>`. There is no ID map to maintain.

A group that doesn't exist yet (added to `entra.yaml` in the same PR) doesn't fail the plan.
It's listed in a warning, skipped, and a Dial policy left with no groups isn't created
until the next apply after the `entra` component has created the group. Group names
must start with `lab-`.

| Attribute | On | Used by |
| --- | --- | --- |
| `#public-routers` | vps01 router | (informational) |
| `#home-routers` | home routers + their tunneler identities | Bind policy `home-routers-bind-home-services` |
| `#home-services` | every service | Bind policy |
| `#home-admin` | Proxmox UIs, Traefik dashboard | Dial policy `admins-dial-home-admin` (`lab-admins`) |
| `#home-data` | PostgreSQL, MariaDB | Dial policy `developers-dial-home-data` (`lab-admins`, `lab-developers`) |
| `#<group object ID>` | auto-enrolled identities | the Dial policies above |

`lab-users`, `lab-media` and `lab-infra` aren't used yet. Add a tier by tagging services
and adding a Dial policy with the group in `entra_groups`. Binding is not per role,
since RBAC is a Dial concern.

Every identity may use every router, and every service may traverse every router
(`#all` edge-router and service-edge-router policies).

## One-time manual setup

### Key Vault secrets (`bancey-vault`)

- `OpenZiti-Controller-CA`: PEM of the controller's root CA, used by the Terraform
  provider to verify `ziti.heimelska.co.uk:1280` (whose certificate comes from the
  controller PKI, not a public CA). It is public material:

  ```bash
  ssh ubuntu@vps01.heimelska.co.uk 'sudo cat /var/lib/ziti-controller/pki/*-root-ca/certs/*-root-ca.cert' > ziti-ca.pem
  az keyvault secret set --vault-name bancey-vault --name OpenZiti-Controller-CA --file ziti-ca.pem
  ```

- `OpenZiti-Admin-Username`, e.g. `admin`
- `OpenZiti-Admin-Password`: at least 16 characters from `A-Z a-z 0-9 ! @ # % ^ _ + ~ . = -`.
  `bootstrap.bash` mangles other characters, so the playbook asserts this.

The password is only used to create the default admin at bootstrap and to log the CLI
in. Rotating it in Key Vault alone does **not** change it in the controller. Run
`ziti edge update authenticator updb -s` first, then update Key Vault.

### OVH edge firewall

UFW on the VPS is opened for 443/tcp, 1280/tcp and 3022/tcp by `vps-hardening.yaml`, but the
OVH Edge Network Firewall in front of it also needs permanent permit rules. Add them
(OVH console, or `ovhcloud ip firewall rule create`) **before** any deny-all rule and
not at sequence 18, which the pipeline reserves:

| Action | Protocol | Source | Dest. port | Option |
| --- | --- | --- | --- | --- |
| permit | tcp | any | | established |
| permit | tcp | any | 443 | |
| permit | tcp | any | 1280 | |
| permit | tcp | any | 3022 | |

Without the port rules, home routers can't enroll and clients can't connect, and
without 443 the public join URL doesn't work. The pipeline's own SSH rule doesn't
cover them.

The edge firewall is stateless. Without the `established` rule, replies to
connections the VPS opens itself are dropped, so HTTPS to anything outside OVH times
out. Examples are the OpenZiti apt repo and key, or `curl https://get.openziti.io` on
the VPS. The Ubuntu mirror still works because it's inside OVH's network, which hides
the problem until something else needs the internet. OVH recommends putting this rule
first (sequence 0).

## Signing in with Entra ID

Clients sign in with Microsoft against the personal tenant instead of importing a JWT.
The pieces:

- **Entra**: the `lab-openziti` app registration (`terraform/environments/prod/entra.yaml`).
  It's a public client (auth code + PKCE) with the redirect URI
  `http://localhost:20314/auth/callback`, which is what the OpenZiti tunnelers listen on.
  There is no client secret. The `entra` component writes the client ID to Key Vault as
  `Entra-OpenZiti-Client-ID`, and the playbook reads it from there.
- **ext-jwt-signer `entra`**: trusts ID tokens from
  `https://login.microsoftonline.com/<tenant>/v2.0` with `aud` = the client ID, and
  matches identities on the `oid` claim (`claimsProperty: oid`, external IDs).
- **auth-policy `entra`**: allows primary ext-JWT from that signer only. Certificate
  and password auth are off.
- **Auto-enrollment**: the signer has `enrollToTokenEnabled` (not `enrollToCertEnabled`).
  The first sign-in creates an identity named from the `preferred_username` claim, with
  external ID = the user's `oid` and auth policy `entra`. Nothing per user is kept in
  the repo.

### Token enrollment, not certificates

Every connection is a user session: the client signs in with Entra, and nothing
long-lived is left on the device. This was chosen over certificate enrollment because:

- **Revocation goes through Entra.** Disabling a user, removing their sign-in or
  changing sign-in policy takes effect at their next connection. A cert-enrolled device
  keeps its client cert whatever happens in Entra, so it had to be deleted in Ziti too.
- **Lost or stolen devices** hold no Ziti credential. They hold whatever Entra
  sign-in state the browser or app keeps, so a stolen *unlocked* device may still
  re-authenticate silently. Entra session lifetimes and the device lock limit that.
- **One identity per user.** Enrollment rejects a second identity with the same
  external ID (`duplicate identity found for external id`). With token auth, every
  device just signs in as that one identity.
- **Mobile.** Ziti Mobile Edge never sent an enrollment request while the signer only
  allowed cert enrollment. The client API advertises the allowed modes, so it appears
  to support token enrollment only.

The cost is a sign-in on connect, and sessions that may end when the Entra ID token
expires (about an hour). Check how the clients handle that.

### Token type

Clients present the **ID token** (`targetToken: ID`, `audience: <client-id>`). An Entra
access token requested with only `openid profile email offline_access` is issued for
Microsoft Graph. Its audience is Graph and it's signed for Graph, so the controller
can't verify it. Using `ACCESS` would need an exposed API scope (`api://<client-id>/ziti`)
on the app registration, which the `entra` component doesn't support yet. Change the
signer only if a client turns out to need an access token.

### Adding a user

1. Add the user to the tenant. App assignment isn't required, so any tenant user can
   sign in and get an identity, but without a role attribute it can't dial anything.
2. In Ziti Desktop Edge, add an identity by URL with `https://join.ziti.heimelska.co.uk`,
   choose the **entra** provider and sign in with Microsoft. No JWT file is involved.
   Don't use `ziti.heimelska.co.uk:1280` for this. Its certificate comes from the
   controller's own PKI, which the OS doesn't trust, so the client rejects it.
3. Add them to the right groups in `entra.yaml`. A brand-new identity gets its group
   attributes from the groups claim when it enrolls. After that, the
   [group attribute sync](#group-attribute-sync) keeps them in line with Entra.

The controller only applies the groups claim at enrollment (verified). Re-authenticating
doesn't refresh the attributes, and there is no controller setting to make it do so. Without
the sync, a user added to or removed from a group would keep their old attributes, and a
removal would leave stale access. The playbook never touches these attributes.

### Client support and open questions

- Ziti Desktop Edge for Windows needs **2.5.2 or later** for external providers. Record
  the tested client, OS and OpenZiti versions here once verified.
- Tested so far:
  - Joining by URL from macOS and Ziti Mobile Edge for Android. A tenant member signs in
    as their existing identity.
  - After joining at `join.ziti.heimelska.co.uk`, clients talk to the controller at
    `ziti.heimelska.co.uk:1280`, so they don't depend on the Let's Encrypt cert after that.
  - Guest (B2B) users' tokens are accepted. Their `oid` is the guest object in this
    tenant.
- Still to test:
  - That token enrollment creates identities from Ziti Mobile Edge, for example for a
    guest user who has never enrolled.
  - Session length: what each client does when the Entra ID token expires.
  - The `tls: bad record MAC` handshake errors that Ziti Mobile Edge produces on `:443`
    before each sign-in. They aren't blocking.
- `enrollAttributeClaimsSelector` attributes are only set at enrollment, not on later
  sign-ins. The [group attribute sync](#group-attribute-sync) corrects them afterwards,
  including for identities enrolled before `/groups` was set.

### Group attribute sync

`scripts/sync-ziti-identity-attributes.sh` makes the Entra group attributes of every
OIDC-enrolled identity match the user's current membership:

1. Reads the `lab-*` security groups and their **transitive** user members from Microsoft
   Graph (nested groups expanded, guest users included).
2. Logs the CLI in to `ziti.heimelska.co.uk:1280` with the admin credentials and the
   controller CA, and lists every identity.
3. Matches identities on `externalId`, which is the user's `oid` (the signer's
   `claimsProperty`). Identities without one, such as router tunnelers and JWT identities, are
   skipped.
4. For each identity, sets the `lab-*` group object IDs to the groups the user is in now. It
   only adds or removes attributes that are IDs of current `lab-*` groups, and keeps every
   other attribute (`home-routers`, anything granted by hand). An identity is only updated
   when its group set differs, so a run with nothing to change does nothing. A user in no
   groups ends up with no group attributes, but the identity isn't deleted.
5. Logs one line per changed identity: its name and the groups added and removed.

The signer keeps `enroll_attr_claims_selector: /groups`, so a brand-new identity can dial
straight away. The sync only corrects drift after that.

**Safety.** The script exits non-zero before changing anything if a Graph call fails,
Graph returns no `lab-*` security groups, the Ziti login fails, or the identity list is
incomplete (`totalCount` doesn't match). A bad read never strips everyone's access. The
admin username, password and CA come only from environment variables, never arguments.
The script discards the CLI's login output (it contains the session token) and keeps its
own session in a temporary `ZITI_CONFIG_DIR`, deleted on exit. The `ziti` CLI can only take
the password as `-p`, so it's briefly in the process list on the agent, as in the Ansible
role.

An attribute that is the ID of a **deleted** `lab-*` group isn't recognised as a group any
more, so it's left in place. That's harmless: Terraform only resolves existing groups, so
no policy selects it.

Entra's groups claim overage (over 200 groups in a token) doesn't matter here. The sync
reads Graph, not tokens.

#### Run modes

- **On every apply** of `terraform/components/openziti`: `terraform_data.sync_identity_attributes`
  (`sync.tf`) has `triggers_replace = timestamp()` and runs the script with `local-exec`
  after the policies, services and configs. A provisioner only runs on apply, so PR plans
  never run the sync, but **every plan, including PR plans, shows this resource being
  replaced**. That's expected and not drift. The Key Vault values are passed through the
  provisioner's `environment` wrapped in `nonsensitive()`. Otherwise Terraform would hide
  all of the provisioner's output, including the change log and any error. The environment
  doesn't appear in the plan or the state.
- **Every 15 minutes** from `ziti-sync-pipeline.yaml` (`trigger: none`, `pr: none`, a
  `main` schedule with `always: true`), so a removal takes effect without a repo change.
  It reads the three `OpenZiti-*` secrets from Key Vault inside one `AzureCLI@2` task and runs
  the script there. It has a `dryRun` parameter for manual runs.

So after a user is **removed** from a group, they keep access for up to 15 minutes, until
the next scheduled run. Delete their identity, or run the script by hand, if that's too
long.

Both modes install the `ziti` CLI pinned to **v2.0.6**, the latest release when this was
written. The controller installs the latest package (`openziti_version: ""`), so bump the
pin in `infra-pipeline.yaml` (`prod_openziti` `preSteps`) and `ziti-sync-pipeline.yaml`
together when the controller moves to a new major or minor version. The flags used were
checked against the v2.0.6 source: `edge login --ca <file>`, `edge list identities -j`
(the raw API response: `.data[].externalId`, `.data[].roleAttributes`,
`.meta.pagination.totalCount`) and `edge update identity <id> --role-attributes a,b`. That
flag replaces the whole list, and an empty value clears it.

#### Azure authentication

The script uses the current `az` session if there is one. Otherwise it runs
`az login --service-principal` from `ARM_CLIENT_ID`, `ARM_TENANT_ID` and `ARM_CLIENT_SECRET`
(or `ARM_OIDC_TOKEN`), into a temporary `AZURE_CONFIG_DIR`, so the caller's `az` state is
left alone.

The reason: what `steps/terraform.yaml@azuredevops-lib` leaves behind can't be seen from
this repo. What the repo does rely on is the `ARM_*` variables, since the `azuread`
provider in `entra` and `openziti` authenticates from them (see
`terraform/components/entra/init.tf`). If the template also leaves `az` logged in, the
script uses that session. The scheduled pipeline runs inside `AzureCLI@2`, so `az` is logged
in there.

Reading membership with the `azuread` provider and passing JSON to the script was
rejected. The scheduled pipeline would still need its own Graph read, which means two
implementations of the same logic.

#### Prerequisites

- **Graph permissions.** The `BTCS-PRODUCTION` service principal already has
  `Group.ReadWrite.All` and `User.Read.All` (see `docs/sso-operations.md`). That covers
  listing groups and their transitive members. The `openziti` component already lists the
  `lab-*` groups with the same principal. Reading members has only been checked against the
  documentation, so the first run confirms it.
- **Key Vault.** No new secrets. It reuses `OpenZiti-Admin-Username`,
  `OpenZiti-Admin-Password` and `OpenZiti-Controller-CA`.
- **Azure DevOps.** Register `ziti-sync-pipeline.yaml` as a new pipeline by hand (Pipelines →
  New pipeline → existing YAML file). Give it access to the `BTCS-PRODUCTION` service
  connection and the `bancey` GitHub connection on its first run. Schedules only apply once
  the YAML is on `main`.
- **Agent minutes.** 96 runs a day on Microsoft-hosted agents add up, at roughly one to two
  minutes each, mostly the CLI download. If the project is on the free private-project
  allowance, check usage after the first few days. Widening the cron interval is the
  simple fix, at the cost of a longer revocation delay.

#### Running it by hand

From a machine logged in to `az` against the lab tenant, with the CLI installed:

```bash
export ZITI_ADMIN_USERNAME="$(az keyvault secret show --vault-name bancey-vault --name OpenZiti-Admin-Username --query value -o tsv)"
export ZITI_ADMIN_PASSWORD="$(az keyvault secret show --vault-name bancey-vault --name OpenZiti-Admin-Password --query value -o tsv)"
export ZITI_CONTROLLER_CA="$(az keyvault secret show --vault-name bancey-vault --name OpenZiti-Controller-CA --query value -o tsv)"
./scripts/sync-ziti-identity-attributes.sh --dry-run
```

Drop `--dry-run` to apply. Or run `ziti-sync-pipeline.yaml` manually, with or without the
`dryRun` parameter.

### Public join URL

Joining by URL has no JWT to carry the controller's CA, so the OS has to trust the
certificate the controller presents. The controller's own PKI isn't trusted, so a
second web listener serves the client API (`edge-client`, `edge-oidc`, no management
APIs) on `join.ziti.heimelska.co.uk:443` with a Let's Encrypt certificate.

- The certificate is bound with `alt_server_certs`, which the controller selects by
  SNI. The name must not overlap the PKI cert's SANs (`ziti.heimelska.co.uk`), so
  don't replace it with a `*.heimelska.co.uk` wildcard. Routers and enrolled clients
  keep using `ziti.heimelska.co.uk:1280` and the PKI.
- certbot on the VPS issues it with a Cloudflare DNS-01 challenge, using
  `Cloudflare-Lab-API-Token`. Nothing listens on port 80. `certbot.timer` renews it, and
  the deploy hook (`/usr/local/bin/openziti-public-cert-deploy.sh`) copies it to
  `/var/lib/ziti-controller/public-tls` and restarts the controller.
- The controller is allowed to bind 443 by a systemd drop-in
  (`ziti-controller.service.d/bind-privileged-ports.conf`, `CAP_NET_BIND_SERVICE`).
- `bootstrap.bash` only writes `config.yml` once, so the playbook edits it: it rebuilds
  the `client-public` listener from `client-management` on every run. The first edit
  rewrites the file without its comments. The previous version is kept next to it as
  `config.yml.<timestamp>~`.

Check it from anywhere:

```bash
curl -sf https://join.ziti.heimelska.co.uk/edge/client/v1/version | jq .data.version
```

A network JWT (`/edge/client/v1/network-jwts`) is the fallback for clients that can't
join by URL. It's one file for the whole network, not per user, and it isn't secret.

### JWT identities

`openziti_identities` still creates identities with a one-time JWT, for devices that
can't do OIDC (e.g. headless `ziti-edge-tunnel`). The JWT is written to
`/opt/openziti/artifacts/<name>.jwt` on the VPS. Fetch it and delete it:

```bash
ssh ubuntu@vps01.heimelska.co.uk sudo cat /opt/openziti/artifacts/<name>.jwt > <name>.jwt
ssh ubuntu@vps01.heimelska.co.uk sudo rm /opt/openziti/artifacts/<name>.jwt
```

JWTs expire after 3 hours by default (the controller's `enrollment` duration). To
reissue one, run `sudo ziti edge delete identity <name>` on the VPS and re-run the
pipeline.

Removing an entry from `openziti_identities` doesn't delete the identity. The Phase 1
`phase1-test-user` was removed from group vars, so delete it on the VPS by hand:

```bash
sudo ziti edge delete identity phase1-test-user
sudo rm -f /opt/openziti/artifacts/phase1-test-user.jwt
```

## Adding a service

Append to `services` in `terraform/environments/prod/openziti.yaml`:

```yaml
  - name: grafana
    role_attributes: [home-services, home-admin]   # home-services + one access tier
    intercept_addresses: [grafana.tiny.heimelska.co.uk]   # what clients dial
    port: 443
    host_address: 10.151.24.10            # where the home routers send it
    # host_port: 8443                     # if it differs from port
```

Intercept the real hostname rather than `*.ziti`, so TLS certificates and OIDC redirect
URIs keep working. While Twingate runs, a device with both clients conflicts on the same
name: disconnect Twingate to test, or set `twingate.is_active: false` on the resource in
`dns.yaml` to move it fully to Ziti.

Both private routers (`openziti` on 10.151.14.0/24, `nebula`) must reach the target.
Test with `nc -vz <host> <port>` from each before publishing.

### First apply after the Ansible role stopped owning the model

The policies, `wanda-pve` service and its configs predate the Terraform component. The
three policies are in `openziti.yaml` under the same names, so import them rather than
recreate them (IDs from `sudo ziti edge list edge-router-policies` etc.):

```bash
cd terraform/components/openziti
terraform import -var-file=../../environments/prod/prod.tfvars 'ziti_edge_router_policy.this["all-identities-all-routers"]' <id>
terraform import -var-file=../../environments/prod/prod.tfvars 'ziti_service_edge_router_policy.this["all-services-all-routers"]' <id>
terraform import -var-file=../../environments/prod/prod.tfvars 'ziti_service_policy.this["home-routers-bind-home-services"]' <id>
```

Delete the Phase 1 leftovers, which Terraform doesn't know about:

```bash
sudo ziti edge delete service wanda-pve
sudo ziti edge delete config wanda-pve-intercept wanda-pve-host
sudo ziti edge delete service-policy users-dial-home-services
```

## Validation

1. `ssh ubuntu@vps01.heimelska.co.uk sudo ziti edge list edge-routers`: all three
   routers online (`ONLINE: true`).
2. `sudo ziti edge list terminators` shows each service with a terminator from
   both `openziti` and `nebula`.
3. Sign in as an identity in `lab-admins`: the Proxmox UIs
   (`https://hela.heimelska.co.uk:8006` etc.), `traefik.tiny.heimelska.co.uk` and both
   databases work.
4. Sign in as a `lab-developers`-only identity: the databases work and the Proxmox UIs and
   Traefik dashboard don't. `sudo ziti edge policy-advisor identities <name> <service>` shows
   why.
5. Remove a service from `openziti.yaml`: the next apply deletes it from the controller.
6. Stop `ziti-router` on one home router; the services keep working through the
   other.
7. From outside the LAN with the tunneller off, nothing new at home is reachable. The
   only new public surface is 443/1280/3022 on the VPS.

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
sudo certbot delete --cert-name join.ziti.heimelska.co.uk   # public join URL cert
sudo rm -f /usr/local/bin/openziti-public-cert-deploy.sh /etc/letsencrypt/cloudflare-openziti.ini
sudo rm -rf /etc/systemd/system/ziti-controller.service.d
sudo apt purge -y openziti-controller openziti-router openziti
sudo rm -rf /var/lib/ziti-controller /var/lib/ziti-router /opt/openziti /root/.config/ziti

# nebula
sudo systemctl disable --now ziti-router
sudo apt purge -y openziti-router openziti && sudo rm -rf /var/lib/ziti-router
```

For the VM, remove `virtual_machines.openziti` from `prod.tfvars`. Then drop the hosts
from the `openziti_*` inventory groups, the DNS entries (`ziti.heimelska.co.uk` and
`join.ziti.heimelska.co.uk` in `cloudflare_records`, `openziti.heimelska.co.uk` in `dns.yaml`), the Ziti ports in
`ansible/group_vars/cloud.yaml`, and the OVH firewall rules.

## Next phases

- **Cutover**: move the remaining Twingate resources into `openziti.yaml`, then
  remove the `twingate` component, connectors and k8s release. Remove the public
  `hass.heimelska.co.uk` record and close the home router's 443 port-forward, so
  Home Assistant is only reachable over Ziti. The pipeline's own access to home hosts
  also needs moving off Twingate, e.g. a ziti-edge-tunnel step on the agent.
- The group attribute sync is a workaround for attributes only being set at enrollment.
  Drop it, along with `ziti-sync-pipeline.yaml`, if OpenZiti gains a way to refresh claims
  on authentication. Until then, consider shortening the 15-minute revocation delay if it
  matters, for example by also triggering the pipeline from an Entra audit event.
- Move the signer and auth policy into Terraform once the provider supports enrollment
  fields. Consider a dedicated mTLS admin identity for the provider instead of the admin
  password. Identity enrollment tokens would be stored in Terraform state, so keep
  Terraform off identities.
