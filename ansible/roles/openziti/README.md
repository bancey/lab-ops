# OpenZiti Role

Installs and bootstraps an OpenZiti controller and edge routers from the official
Linux packages, then tags the router identities and configures Entra sign-in. The network
model (policies, services) is owned by `terraform/components/openziti`.
Used by `ansible/openziti.yaml`. The architecture and runbook are in
[`docs/openziti.md`](../../../docs/openziti.md).

The role has no `main.yaml`. Each entrypoint is included with `tasks_from`, in the
playbook's play order:

| Tasks file | Runs on | Does |
| --- | --- | --- |
| `install` | all | OpenZiti apt repo + `openziti` and `openziti_packages` |
| `router_state` | routers | Records `openziti_router_enrolled` and the `openziti_router` settings as facts |
| `controller` | controller | Non-interactive `bootstrap.bash` (once), public join listener (`public_api`), loopback admin console listener (`console`), starts the service, logs the CLI in |
| `backup` | controller | Nightly age-encrypted DB snapshot + PKI + config to Azure Blob (when `openziti_backup_enabled`) |
| `enroll` | controller | Creates/re-enrolls edge routers for unenrolled routers → `openziti_enrollment_tokens`; enables tunneling on routers switched to a hosting mode |
| `router` | routers | Non-interactive `bootstrap.bash` with the issued token (once), adds the tunnel listener if the mode changed later, starts the service |
| `objects` | controller | Tags router identities; reconciles ext-jwt-signers, auth policies and console admin identities; creates JWT identities |

`public_api` and `console` share `tls_cert`, which issues a Let's Encrypt certificate with a
Cloudflare DNS-01 challenge and installs its renewal deploy hook.

Both bootstrap scripts run only once. After that, `/var/lib/ziti-{controller,router}/config.yml`
is the source of truth, and changing an address or port means editing it by hand or
rebuilding. JWT identities are created if missing but never updated. ext-jwt-signers and
auth policies are patched to match their variables on every run.

In check mode, packages that aren't installed yet and anything that talks to the
controller API are skipped.

## Variables

See `defaults/main.yaml`. The ones most likely to change:

| Variable | Default | Purpose |
| --- | --- | --- |
| `openziti_ctrl_address` / `openziti_ctrl_port` | `ziti.heimelska.co.uk` / `1280` | Controller's public address, baked into its PKI |
| `openziti_admin_username` / `openziti_admin_password` | `admin` / — | Default admin, set from Key Vault by the playbook |
| `openziti_router_advertised_address` | inventory hostname | Set per group in `group_vars/openziti_*_routers.yaml` |
| `openziti_router_public` | member of `openziti_public_routers` | Public: link listener, no tunneler. Private: `--private`, `host` mode |
| `openziti_identities` | `[]` | `{name, role_attributes}`; JWT written to `openziti_artifacts_dir` |
| `openziti_ext_jwt_signers` | `[]` | OIDC providers for client sign-in, optionally auto-enrolling identities |
| `openziti_auth_policies` | `[]` | `{name, cert_allowed, ext_jwt_allowed, ext_jwt_allowed_signers, updb_allowed}` |
| `openziti_public_api_enabled` / `openziti_public_api_address` | `false` / — | Client API on `:443` with a Let's Encrypt cert for join-by-URL; Cloudflare token from Key Vault `Cloudflare-Lab-API-Token` |
| `openziti_console_enabled` / `openziti_console_address` | `false` / — | Ziti Admin Console on a loopback-only listener (`openziti_console_port`, 8441), published as a Ziti service |
| `openziti_console_admins` | `[]` | `{name, external_id}`; admin identities matched on the console token's `sub`, pruned when removed |
| `openziti_version` | latest | Pin all hosts to one release |
| `openziti_backup_enabled` / `openziti_backup_storage_account` | `false` / — | Nightly controller backup; SAS token from Key Vault `OpenZiti-Backup-SAS-Token` |
