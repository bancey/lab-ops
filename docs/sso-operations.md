# Entra ID SSO Operations Runbook

Single sign-on for the lab, federated directly to the Entra ID tenant
`efc9b6c0-5193-43b1-a5a7-2ef3f29cd613`. No self-hosted identity provider.

## Architecture Overview

Two mechanisms, chosen per application:

- **Native OIDC** where the app speaks it, so the app itself can map Entra groups onto its own
  roles. Grafana, Vikunja, Paperless-ngx, Proxmox, Gatus, Headlamp.
- **Traefik forwardAuth via oauth2-proxy** (`provider: entra-id`) for everything else. One
  oauth2-proxy Deployment per cluster; per-application authorization is expressed by passing
  `?allowed_groups=<object-id>` on the `/oauth2/auth` URL, so an access tier costs a Middleware
  rather than another Deployment.

Everything Entra-side is managed as code by `terraform/components/entra`, driven by
`terraform/environments/prod/entra.yaml`.

### Request flow (forwardAuth)

1. Traefik calls oauth2-proxy `/oauth2/auth?allowed_groups=<id>`.
2. Signed in and in the group → `202`, request proceeds with `X-Auth-Request-*` headers.
3. Not signed in → `401`. The `oauth2-errors` middleware catches it, fetches
   `/oauth2/start?rd=<original absolute URL>` and rewrites the status to `302`, so the browser
   follows straight to Entra with no interstitial. Traefik's `{url}` placeholder expands to the
   full `scheme://host/path?query`, so deep links survive.
4. Signed in but **not** in the group → `403`. Deliberately not in `oauth2-errors`' status list,
   so the user sees Forbidden instead of a redirect loop.

`oauth2-errors` must come **before** the forwardAuth in each chain, or the 401 is never caught.

### Single sign-on across clusters

Both clusters' oauth2-proxy instances share the same `cookie-secret` and the cookie name
`_lab_oauth2_proxy`, with `--cookie-domain=.heimelska.co.uk`. One login therefore covers both
`tiny` and `wanda`. If the cookie secrets ever diverge, users get a second (silent) Entra round
trip when crossing clusters.

## Entra free tier

Microsoft 365 Business Basic includes Entra ID Free. The constraints that shape this design:

- **Group-based assignment to enterprise apps needs Entra ID P1.** So applications are left open
  to the tenant (`app_role_assignment_required = false`) and authorization is enforced downstream
  from the groups claim. Do not turn on "User assignment required".
- The `groups` optional claim itself is free, and everything here depends on it.
- Conditional Access is P1 and out of scope. Twingate remains the network perimeter.
- **The groups claim carries object IDs, not display names.** Every `allowed_groups`, Grafana
  `role_attribute_path`, Proxmox group and Kubernetes RBAC subject uses the GUID.

## Groups

| Group | Purpose |
|---|---|
| `lab-admins` | `c01110e9-c46f-40b7-bc58-4832a4b4e11b`. Kubernetes cluster-admin, Proxmox, Traefik dashboard, BunkerWeb UI, Home Assistant sidecars. |
| `lab-users` | Household. Glance, Monica, Stirling-PDF, Vikunja, Paperless. |
| `lab-media` | Sonarr, Radarr, Prowlarr, SABnzbd. |
| `lab-infra` | Smokeping and other monitoring UIs. |

Membership is declared in `terraform/environments/prod/entra.yaml` but managed with individual
`azuread_group_member` resources, so adding someone through the portal in a hurry is not undone
by the next apply.

## Coverage

**True SSO — the Entra login is the only login:**

| Application | Mechanism |
|---|---|
| Sonarr, Radarr, Prowlarr | forwardAuth `chain-media` + `AuthenticationMethod=External` in `config.xml` |
| Glance, Smokeping, Stirling-PDF | forwardAuth (these had no authentication at all before) |
| Home Assistant code-server, Zigbee2MQTT, Node-RED | forwardAuth `chain-admins` (code-server ran `--auth none`) |
| Traefik dashboard | forwardAuth `chain-admins`, replacing the basic-auth secret |
| Grafana | native OIDC, groups mapped to Admin/Viewer |
| Vikunja, Paperless-ngx | native OIDC |
| Headlamp, kubectl | native OIDC (pre-existing) |
| Proxmox | native OIDC realm |
| Gatus | native OIDC |

**Gated, not SSO'd — the app keeps its own login behind the Entra one, so users sign in twice.**
This is defence in depth, not convenience:

| Application | Why |
|---|---|
| SABnzbd | No external-auth mode; keeps its own login and API key |
| Monica | No OIDC support |
| BunkerWeb UI | Keeps its own admin + TOTP |

**Deliberately not gated:**

| Application | Why |
|---|---|
| Home Assistant (`hass.*`) | The one internet-exposed app. Companion mobile apps and webhooks use long-lived tokens that a browser redirect flow breaks. |
| Jellyfin, Plex | TV and mobile clients cannot complete a browser OIDC redirect. |
| Pelican | The Wings daemon calls the panel API; forwardAuth would break node communication. Needs a path-based bypass for `/api/remote` first. |
| VictoriaMetrics, VictoriaLogs | The Pi swarm's Alloy pushes to `/api/v1/write` and `/insert/loki/api/v1/push` over these Ingresses. Gating the whole host breaks metrics and log ingestion — see "Known follow-ups". |
| `auth.tiny` / `auth.wanda` | Serves the sign-in redirect and callback. Gating it is a redirect loop. |
| Headlamp | Already native OIDC; forwardAuth on top would mean two logins. |

## First-time setup

### 1. Grant the deploying service principal Graph permissions

The `BTCS-PRODUCTION` service connection SP (`MSDN New`) has Azure RBAC but **no Microsoft Graph
permissions**, so it cannot touch the directory until this is done once, by hand, as Global
Administrator.

| Graph permission | App role ID | Why |
|---|---|---|
| `Application.ReadWrite.OwnedBy` | `18a4783c-866b-4cc7-a460-3d0e455a5d06` | Manage the app registrations, service principals and client secrets it creates |
| `Group.ReadWrite.All` | `62a82d76-70ea-41e2-9197-370581804d09` | Manage the `lab-*` security groups and membership |
| `User.Read.All` | `df021288-bdef-4463-88db-98f22de89214` | Resolve group members by UPN |

```bash
SP_ID=$(az ad sp list --display-name "MSDN New" --query "[0].id" -o tsv)
GRAPH_ID=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
for ROLE in 18a4783c-866b-4cc7-a460-3d0e455a5d06 \
            62a82d76-70ea-41e2-9197-370581804d09 \
            df021288-bdef-4463-88db-98f22de89214; do
  az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignments" \
    --body "{\"principalId\":\"$SP_ID\",\"resourceId\":\"$GRAPH_ID\",\"appRoleId\":\"$ROLE\"}"
done
```

`Application.ReadWrite.OwnedBy` is deliberate: the broader `Application.ReadWrite.All`, or the
Application Administrator directory role, would let this SP add credentials to *any* app
registration in the tenant. On a principal that also holds subscription Owner, that is a
privilege-escalation path.

### 2. Adopt the two objects that already exist

`Application.ReadWrite.OwnedBy` only sees apps the SP owns, and the pre-existing group and app
registration were created by hand.

```bash
# App registration aff85c5e... backs the K3s API server OIDC and Headlamp
az ad app owner add --id aff85c5e-bc23-48cf-a00b-635674cb74c6 --owner-object-id "$SP_ID"

cd terraform/components/entra
terraform import 'azuread_application.this["lab-kubernetes"]' /applications/<object-id>
terraform import 'azuread_group.this["lab-admins"]'           c01110e9-c46f-40b7-bc58-4832a4b4e11b
```

Import rather than recreate: a new client ID means editing the kube-apiserver OIDC args in
`terraform/components/inventory/hosts.yaml.tpl` and re-issuing both Headlamp secrets.

### 3. Apply the Entra component

Runs as the `prod_entra` stage of `infra-pipeline.yaml`, or locally:

```bash
terraform -chdir=terraform/components/entra plan -var-file=../../environments/prod/prod.tfvars
```

Verify:

```bash
az ad group list --filter "startswith(displayName,'lab-')" --query "[].{name:displayName,id:id}" -o table
az keyvault secret list --vault-name bancey-vault --query "[?starts_with(name,'Entra-')].{name:name,expires:attributes.expires}" -o table
```

### 4. Resolve the group-ID placeholders

The GUIDs do not exist until step 3 has run, so the repo ships placeholders that **fail closed** —
oauth2-proxy returns 403 for an unknown group, and an RBAC subject that resolves to nothing
matches nobody.

```bash
./scripts/set-entra-group-ids.sh --dry-run   # then without --dry-run
```

### 5. Nothing - the SOPS secrets are generated by Terraform

Applying the `entra` component renders every file listed under `kubernetes_secrets` in
`entra.yaml` and commits it. There is no bootstrap step and no script to run by hand.

## Rotating a client secret

Rotation is automated end to end and lives in one place. `terraform/components/entra` owns the
app registration, the client secret, the rendered SOPS file and the commit, so Terraform knows
exactly when a file needs rewriting — it does not have to decrypt anything to find out.

What happens on a rotation:

1. `time_rotating` rolls over, so `azuread_application_password` is replaced.
2. That changes the `spec` hash on the corresponding `terraform_data.sops_secret`, whose
   `local-exec` re-renders the file via `scripts/render-sops-secret.sh`.
3. `github_repository_file` commits the new ciphertext as the GitHub App.
4. Flux applies the Secret, and **Reloader** restarts the workloads that consume it. This is the
   part that actually prevents an outage: oauth2-proxy takes its client secret as an environment
   variable, fixed at pod creation, and Grafana, Vikunja and Paperless all read theirs at
   startup. Flux applying a new Secret changes nothing in the pod spec, so without Reloader they
   would keep using the dead credential. Workloads opt in with
   `secret.reloader.stakater.com/reload: <secret>`.

Nothing is regenerated when nothing changed, because the trigger is a hash of the desired
plaintext rather than a comparison of the encrypted file — which would be useless anyway, since
sops produces different ciphertext every run for identical input.

To force a rotation now:

```bash
terraform -chdir=terraform/components/entra taint 'azuread_application_password.this["lab-grafana"]'
```

Ansible consumers (Proxmox, Gatus) need nothing extra — the pipeline downloads their secrets from
Key Vault fresh on every run.

### The oauth2-proxy cookie secret

`shared_random_secrets.oauth2-proxy-cookie` in `entra.yaml` is a `random_bytes` resource, and both
oauth2-proxy entries reference it, so the two clusters are guaranteed the same value — that is
what lets a session issued by one be accepted by the other. It is not derived from the client
secret and does not change when one rotates. Changing its `length`, or tainting it, regenerates
it and signs everyone out.

## Break glass

| Situation | Recovery |
|---|---|
| Entra or oauth2-proxy down, need Proxmox | `root@pam` still works on every node; the OIDC realm is additive |
| Need Grafana | `/login?disableAutoLogin` shows the admin form; credentials in `grafana-admin-secret.sops.yaml` |
| Need Kubernetes | The k3s `admin` kubeconfig on any control-plane node bypasses OIDC entirely |
| Locked out of everything web | Twingate + `kubectl` remain independent of Entra. `kubectl -n oauth2-proxy scale deploy/oauth2-proxy --replicas=0` does **not** restore access — it makes the middleware fail. Revert the chain on the affected IngressRoute instead. |
| Vikunja / Paperless | Local login is deliberately left enabled on both |

Check the auth layer first when several services fail at once:

```bash
kubectl -n oauth2-proxy logs deploy/oauth2-proxy --tail=100
```

Gatus monitors `https://auth.tiny.heimelska.co.uk/ping` and the wanda equivalent, so an SSO
outage shows up as its own alert rather than as every service failing at once.

## Verification

Unauthenticated request should redirect, not 401:

```bash
curl -sSI https://glance.tiny.heimelska.co.uk/ | head -5
```

```bash
kubectl get middleware -n traefik
```

End to end, per tier:

1. Private window → `https://glance.tiny.heimelska.co.uk` → straight to Entra, then the app.
2. Without re-authenticating → `https://sonarr.wanda.heimelska.co.uk` → **no second login**.
   This is the check that proves the shared cookie secret is right.
3. A `lab-users`-only account on a `chain-admins` host → **403**, not a redirect loop.
4. Prowlarr can still test and sync its Sonarr/Radarr connections (in-cluster API traffic never
   passes through Traefik).
5. Home Assistant companion apps still connect over `hass.heimelska.co.uk`.
6. Pi swarm metrics still arriving in VictoriaMetrics.

## Adding a new application

1. Pick a tier and append the chain to the app's IngressRoute, after `default-headers`:

   ```yaml
         middlewares:
           - name: default-headers
             namespace: traefik
           - name: chain-users
             namespace: traefik
   ```

2. Add a private DNS record in `terraform/environments/prod/dns.yaml` pointing at the cluster LB
   (`10.151.24.10` for tiny, `10.151.24.160` for wanda).
3. Nothing in Entra needs to change — the callback is always the cluster's `auth.<cluster>` host.

Only reach for native OIDC when the app can do something with the groups claim that a yes/no
gate cannot, such as mapping roles. Then add it to `entra.yaml` and run the sync script.

If the app has non-browser clients — mobile apps, TV clients, daemons calling its API — do not
put forwardAuth in front of it. See the "Deliberately not gated" table.

## Known follow-ups

- **VictoriaMetrics / VictoriaLogs** are ungated because the Pi swarm's Alloy pushes to them over
  their Ingresses (`ansible/roles/rpi-monitoring/templates/alloy-config.alloy.j2`). Gating needs
  the Helm `Ingress` replaced with a Traefik `IngressRoute` carrying two rules: a higher-priority
  unauthenticated rule for `PathPrefix('/api/v1/write')` and `/insert/`, and a `chain-infra` rule
  for everything else. Verify ingestion after.
- **Pelican** needs a `PathPrefix('/api/remote')` bypass before the panel can be gated, or the
  Wings daemon on `wings-thor` loses contact.
- **AdGuard Home** has no OIDC and must keep its admin credentials, because the Terraform
  `adguard` provider and `adguard_exporter` both authenticate with them. Gating the UI means
  BunkerWeb's auth plugin on the `adguard.*` vhosts with `/control/*` excluded.
- **Wanda BMC** (`wanda-mgmt`) is appliance-local credentials only.
- **Traefik dashboard basic auth** (`traefik-dashboard-auth.yaml` and its SOPS secret) is left in
  place as the rollback path. Remove both, and drop them from the config `kustomization.yaml`,
  once SSO on the dashboard is confirmed.
- **`docs/migration/replacement-matrix.md` and `target-architecture.md`** describe removing Entra
  ID. That scope is the Azure *subscription*; Entra as an identity provider is now a permanent
  dependency. Both have been annotated.
