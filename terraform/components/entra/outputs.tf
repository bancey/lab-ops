# The groups claim carries object IDs, not names, so these GUIDs are what every downstream
# consumer needs: oauth2-proxy allowed_groups, Grafana role_attribute_path, Proxmox ACLs and the
# Kubernetes ClusterRoleBindings in ansible/templates/cluster-admins.yaml.
output "group_ids" {
  description = "Map of group display name to Entra object ID."
  value       = { for name, group in azuread_group.this : name => group.object_id }
}

output "application_ids" {
  description = "Map of application name to Entra application (client) ID."
  value       = { for name, app in azuread_application.this : name => app.client_id }
}

output "key_vault_secret_names" {
  description = "Map of application name to the Key Vault secret names holding its credentials."
  value = {
    for name, prefix in local.key_vault_prefixes : name => {
      client_id     = "Entra-${prefix}-Client-ID"
      client_secret = contains(keys(local.app_secrets), name) ? "Entra-${prefix}-Client-Secret" : null
    }
  }
}
