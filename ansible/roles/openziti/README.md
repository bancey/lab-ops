# OpenZiti Role

Installs and bootstraps an OpenZiti controller and edge routers from the official
Linux packages, then creates the network model (policies, services, identities).
Used by `ansible/openziti.yaml`. The architecture and runbook are in
[`docs/openziti.md`](../../../docs/openziti.md).

The role has no `main.yaml`. Each entrypoint is included with `tasks_from`, in the
playbook's play order:

| Tasks file | Runs on | Does |
| --- | --- | --- |
| `install` | all | OpenZiti apt repo + `openziti` and `openziti_packages` |
| `router_state` | routers | Records `openziti_router_enrolled` and the `openziti_router` settings as facts |
| `controller` | controller | Non-interactive `bootstrap.bash` (once), starts the service, logs the CLI in |
| `backup` | controller | Nightly age-encrypted DB snapshot + PKI + config to Azure Blob (when `openziti_backup_enabled`) |
| `enroll` | controller | Creates/re-enrolls edge routers for unenrolled routers → `openziti_enrollment_tokens` |
| `router` | routers | Non-interactive `bootstrap.bash` with the issued token (once), starts the service |
| `objects` | controller | Creates missing policies, service configs, services, identities; tags router identities; reconciles ext-jwt-signers and auth policies |

Both bootstrap scripts run only once. After that, `/var/lib/ziti-{controller,router}/config.yml`
is the source of truth, and changing an address or port means editing it by hand or
rebuilding. Objects are created if missing but never updated, except ext-jwt-signers
and auth policies, which are patched to match their variables on every run.

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
| `openziti_services` | `[]` | `{name, role_attributes, intercept_addresses, port, host_address, host_port?}` |
| `openziti_identities` | `[]` | `{name, role_attributes}`; JWT written to `openziti_artifacts_dir` |
| `openziti_ext_jwt_signers` | `[]` | OIDC providers for client sign-in, optionally auto-enrolling identities |
| `openziti_auth_policies` | `[]` | `{name, cert_allowed, ext_jwt_allowed, ext_jwt_allowed_signers, updb_allowed}` |
| `openziti_version` | latest | Pin all hosts to one release |
| `openziti_backup_enabled` / `openziti_backup_storage_account` | `false` / — | Nightly controller backup; SAS token from Key Vault `OpenZiti-Backup-SAS-Token` |
