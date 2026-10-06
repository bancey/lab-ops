# Brings the Entra group role attributes of existing identities in line with current group
# membership. The signer only applies the /groups claim at enrollment, so without this a group
# change never reaches an identity that already exists (see docs/openziti.md).
#
# triggers_replace = timestamp() replaces this on every apply, so the sync runs every time. A
# local-exec only runs on apply, so a PR plan never executes it, but every plan shows this being
# replaced. ziti-sync-pipeline.yaml runs the same script every 15 minutes between applies.
resource "terraform_data" "sync_identity_attributes" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command     = "${local.repo_root}/scripts/sync-ziti-identity-attributes.sh"
    interpreter = ["/bin/bash", "-c"]
    # Through the environment rather than argv, as in components/entra. nonsensitive() because
    # Terraform hides all provisioner output when the config holds a sensitive value, which would
    # hide the per-identity change log and any error. The script never prints these values, and a
    # provisioner's environment appears in neither the plan nor the state.
    environment = {
      ZITI_CONTROLLER_URL = local.openziti.controller_url
      ZITI_ADMIN_USERNAME = nonsensitive(data.azurerm_key_vault_secret.admin_username.value)
      ZITI_ADMIN_PASSWORD = nonsensitive(data.azurerm_key_vault_secret.admin_password.value)
      ZITI_CONTROLLER_CA  = nonsensitive(data.azurerm_key_vault_secret.controller_ca.value)
    }
  }

  # Last, so it runs against the policies this apply has just created or changed.
  depends_on = [
    ziti_edge_router_policy.this,
    ziti_service_edge_router_policy.this,
    ziti_service_policy.this,
    ziti_intercept_v1_config.this,
    ziti_host_v1_config.this,
    ziti_service.this,
  ]
}
